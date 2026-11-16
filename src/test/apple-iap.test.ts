// @vitest-environment node
// App Store purchase → server Pro, against PGlite and fixture JWS (not Apple's root).
import { readFileSync } from "node:fs";
import path from "node:path";
import { beforeAll, describe, expect, it } from "vitest";
import { PGlite } from "@electric-sql/pglite";
import type { Db } from "../../server/db";
import { createApp } from "../../server/app";
import { isProAccount, type AppleSubscriptionLike, type SubscriptionLike } from "../../server/lib/plan";
import { appAccountTokenForUser } from "../../server/lib/apple-entitlement";
import { testChain } from "./apple-jws-fixture";

const A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const users: Record<string, { id: string; email: string; name: string }> = {
  a: { id: A, email: "a@example.test", name: "Alice" },
  b: { id: B, email: "b@example.test", name: "Bob" },
};

let pg: PGlite;
let db: Db;
let app: ReturnType<typeof createApp>;
let roots: string[];
let sign: (payload: Record<string, unknown>) => Promise<string>;

function asDb(p: PGlite): Db {
  return {
    async query(text, params) {
      const r = await p.query(text, params as unknown[]);
      return { rows: r.rows as never[], rowCount: r.affectedRows ?? r.rows.length };
    },
  };
}

async function call(who: "a" | "b" | null, method: string, url: string, body?: unknown) {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (who) headers["x-test-user"] = who;
  const res = await app.fetch(new Request(`https://tokeny.test${url}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  }));
  const text = await res.text();
  let json: Record<string, unknown> | null = null;
  try { json = JSON.parse(text); } catch { /* not json */ }
  return { status: res.status, json };
}

function transaction(userId: string, over: Record<string, unknown> = {}) {
  return {
    transactionId: "2000000000000001",
    originalTransactionId: "2000000000000001",
    bundleId: "cz.martinpohl.tokeny",
    productId: "cz.martinpohl.tokeny.pro.yearly",
    purchaseDate: Date.parse("2026-11-01T00:00:00Z"),
    expiresDate: Date.parse("2027-11-01T00:00:00Z"),
    type: "Auto-Renewable Subscription",
    environment: "Sandbox",
    signedDate: Date.parse("2026-11-16T08:00:00Z"),
    appAccountToken: appAccountTokenForUser(userId),
    ...over,
  };
}

async function notification(type: string, tx: Record<string, unknown>, extra: Record<string, unknown> = {}) {
  const signedTransactionInfo = await sign(tx);
  const renewal = extra.renewal as Record<string, unknown> | undefined;
  const signedRenewalInfo = renewal ? await sign(renewal) : undefined;
  return sign({
    notificationType: type,
    subtype: extra.subtype ?? undefined,
    notificationUUID: `00000000-0000-4000-8000-${String(extra.n ?? 1).padStart(12, "0")}`,
    data: {
      bundleId: tx.bundleId,
      environment: tx.environment,
      signedTransactionInfo,
      signedRenewalInfo,
      status: extra.status,
    },
    version: "2.0",
    signedDate: tx.signedDate,
  });
}

beforeAll(async () => {
  const chain = await testChain();
  roots = [chain.rootPem];
  sign = (payload) => chain.sign(payload);
  pg = new PGlite();
  await pg.exec(`
    create schema neon_auth;
    create table neon_auth."user" (id uuid primary key, name text, email text, "emailVerified" boolean default false,
      image text, "createdAt" timestamptz default now(), "updatedAt" timestamptz default now());
  `);
  const schema = readFileSync(path.resolve(__dirname, "../../db/schema.sql"), "utf8").replace(/CREATE EXTENSION[^;]*;/i, "");
  await pg.exec(schema);
  for (const u of Object.values(users)) {
    await pg.query('insert into neon_auth."user" (id, name, email) values ($1, $2, $3)', [u.id, u.name, u.email]);
  }
  db = asDb(pg);
  app = createApp({
    db: () => db,
    appleRoots: roots,
    sessionUser: async (req) => {
      const u = users[req.headers.get("x-test-user") ?? ""];
      return u ? { ...u, image: null, emailVerified: true } : null;
    },
  });
}, 60_000);

describe("SQL / plan parity", () => {
  it("public.is_pro matches isProAccount for Stripe and App Store rows", async () => {
    const cases: { name: string; stripe: SubscriptionLike | null; apple: AppleSubscriptionLike | null; want: boolean }[] = [
      { name: "neither", stripe: null, apple: null, want: false },
      { name: "stripe active", stripe: { status: "active", current_period_end: "2027-01-01T00:00:00Z" }, apple: null, want: true },
      { name: "stripe ended", stripe: { status: "active", current_period_end: "2020-01-01T00:00:00Z" }, apple: null, want: false },
      {
        name: "apple active",
        stripe: null,
        apple: { status: "active", expires_at: "2027-01-01T00:00:00Z", revocation_date: null, grace_expires_at: null },
        want: true,
      },
      {
        name: "apple expired",
        stripe: null,
        apple: { status: "active", expires_at: "2020-01-01T00:00:00Z", revocation_date: null, grace_expires_at: null },
        want: false,
      },
      {
        name: "apple revoked",
        stripe: null,
        apple: { status: "active", expires_at: "2027-01-01T00:00:00Z", revocation_date: "2020-06-01T00:00:00Z", grace_expires_at: null },
        want: false,
      },
      {
        name: "grace",
        stripe: null,
        apple: { status: "grace", expires_at: "2020-01-01T00:00:00Z", revocation_date: null, grace_expires_at: "2027-01-01T00:00:00Z" },
        want: true,
      },
      {
        name: "billing retry",
        stripe: null,
        apple: { status: "billing_retry", expires_at: "2020-01-01T00:00:00Z", revocation_date: null, grace_expires_at: null },
        want: false,
      },
      {
        name: "refunded",
        stripe: { status: "canceled", current_period_end: "2020-01-01T00:00:00Z" },
        apple: { status: "refunded", expires_at: "2027-01-01T00:00:00Z", revocation_date: "2026-01-01T00:00:00Z", grace_expires_at: null },
        want: false,
      },
    ];
    for (const [i, c] of cases.entries()) {
      const id = `dddddddd-dddd-4ddd-8ddd-${String(i).padStart(12, "0")}`;
      await pg.query('insert into neon_auth."user" (id, name, email) values ($1, $2, $3)', [id, c.name, `${i}@example.test`]);
      if (c.stripe) {
        await pg.query(
          `insert into subscriptions (user_id, stripe_customer_id, stripe_subscription_id, status, current_period_end)
           values ($1, $2, $3, $4, $5)`,
          [id, `cus_${i}`, `sub_${i}`, c.stripe.status, c.stripe.current_period_end],
        );
      }
      if (c.apple) {
        await pg.query(
          `insert into apple_subscriptions (
             original_transaction_id, user_id, product_id, bundle_id, environment, status,
             app_account_token, latest_transaction_id, expires_at, revocation_date, grace_expires_at, signed_date)
           values ($1, $2, 'cz.martinpohl.tokeny.pro.monthly', 'cz.martinpohl.tokeny', 'Production', $3,
                   $2, $1, $4, $5, $6, now())`,
          [id, id, c.apple.status, c.apple.expires_at, c.apple.revocation_date, c.apple.grace_expires_at],
        );
      }
      const sql = (await db.query<{ pro: boolean }>("select public.is_pro($1::uuid) as pro", [id])).rows[0].pro;
      expect(sql, c.name).toBe(c.want);
      expect(isProAccount(c.stripe, c.apple ? [c.apple] : [], new Date()), c.name).toBe(c.want);
    }
  });
});

describe("POST /api/apple/transactions", () => {
  it("requires a session", async () => {
    expect((await call(null, "POST", "/api/apple/transactions", { signedTransactions: ["x"] })).status).toBe(401);
  });

  it("rejects a JWS that does not chain to the configured root", async () => {
    const strict = createApp({
      db: () => db,
      sessionUser: async (req) => {
        const u = users[req.headers.get("x-test-user") ?? ""];
        return u ? { ...u, image: null, emailVerified: true } : null;
      },
    });
    const jws = await sign(transaction(A));
    const res = await strict.fetch(new Request("https://tokeny.test/api/apple/transactions", {
      method: "POST",
      headers: { "content-type": "application/json", "x-test-user": "a" },
      body: JSON.stringify({ signedTransactions: [jws] }),
    }));
    expect(res.status).toBe(400);
  });

  it("grants the caller Pro and refuses to attach the same transaction to someone else", async () => {
    const old = new Date(Date.now() - 60 * 86_400_000).toISOString();
    expect((await call("a", "POST", "/api/activity/import", {
      rows: [{ generation_id: "old-a", created_at: old, cost_total: 1, model_permaslug: "m", provider_name: "OpenAI", tokens_prompt: 1, tokens_completion: 1 }],
    })).status).toBe(200);
    expect((await call("a", "GET", "/api/activity")).json?.rows).toEqual([]);

    const jws = await sign(transaction(A));
    const ok = await call("a", "POST", "/api/apple/transactions", { signedTransactions: [jws] });
    expect(ok.status).toBe(200);
    expect(ok.json).toMatchObject({ isPro: true, accepted: 1 });
    expect((await call("a", "GET", "/api/usage-summary")).json?.plan).toBe("pro");
    expect((await call("a", "GET", "/api/activity")).json?.rows).toHaveLength(1);
    expect((await call("a", "GET", "/api/subscription")).json?.appStore).toMatchObject({
      productId: "cz.martinpohl.tokeny.pro.yearly",
      environment: "Sandbox",
      status: "active",
    });
    expect((await call("b", "GET", "/api/usage-summary")).json?.plan).toBe("free");

    const stolen = await call("b", "POST", "/api/apple/transactions", { signedTransactions: [jws] });
    expect(stolen.status).toBe(403);
    expect(stolen.json).toMatchObject({ error: "app_account_token_mismatch" });

    const relabeled = await sign(transaction(B, { signedDate: Date.parse("2026-11-16T09:00:00Z") }));
    const conflict = await call("b", "POST", "/api/apple/transactions", { signedTransactions: [relabeled] });
    expect(conflict.status).toBe(409);
    expect((await db.query("select user_id::text as user_id from apple_subscriptions where original_transaction_id = '2000000000000001'")).rows).toEqual([
      { user_id: A },
    ]);
  });

  it("ignores an older signed transaction, so a stale device cannot roll a renewal back", async () => {
    const older = await sign(transaction(A, { expiresDate: Date.parse("2026-12-01T00:00:00Z"), signedDate: Date.parse("2026-11-01T00:00:00Z") }));
    const again = await call("a", "POST", "/api/apple/transactions", { signedTransactions: [older] });
    expect(again.status).toBe(200);
    const { rows } = await db.query<{ expires_at: Date | string }>(
      "select expires_at from apple_subscriptions where original_transaction_id = '2000000000000001'",
    );
    expect(new Date(rows[0].expires_at).toISOString().startsWith("2027-11-01")).toBe(true);
  });
});

describe("POST /api/apple/notifications", () => {
  it("rejects a bad payload and ignores a token that names nobody", async () => {
    expect((await call(null, "POST", "/api/apple/notifications", { signedPayload: "nope" })).status).toBe(400);
    const stranger = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
    const signedPayload = await notification("DID_RENEW", transaction(stranger, {
      originalTransactionId: "3000000000000003",
      transactionId: "3000000000000009",
    }), { n: 2 });
    const res = await call(null, "POST", "/api/apple/notifications", { signedPayload });
    expect(res.status).toBe(200);
    expect(res.json).toMatchObject({ applied: false });
    expect((await db.query("select 1 from apple_subscriptions where original_transaction_id = '3000000000000003'")).rows).toEqual([]);
  });

  it("extends, expires, refunds and records a renewal-status change for the bound user", async () => {
    const renewed = transaction(A, {
      transactionId: "2000000000000002",
      expiresDate: Date.parse("2028-11-01T00:00:00Z"),
      signedDate: Date.parse("2027-11-01T00:00:00Z"),
    });
    const renew = await call(null, "POST", "/api/apple/notifications", {
      signedPayload: await notification("DID_RENEW", renewed, { n: 3, renewal: { originalTransactionId: renewed.originalTransactionId, autoRenewStatus: 1 } }),
    });
    expect(renew.json).toMatchObject({ ok: true, applied: true });
    expect((await call("a", "GET", "/api/usage-summary")).json?.plan).toBe("pro");

    const turnedOff = await call(null, "POST", "/api/apple/notifications", {
      signedPayload: await notification("DID_CHANGE_RENEWAL_STATUS", transaction(A, {
        transactionId: "2000000000000002",
        expiresDate: Date.parse("2028-11-01T00:00:00Z"),
        signedDate: Date.parse("2027-11-02T00:00:00Z"),
      }), { n: 4, subtype: "AUTO_RENEW_DISABLED" }),
    });
    expect(turnedOff.json).toMatchObject({ applied: true });
    expect((await db.query("select auto_renew_status, status from apple_subscriptions where user_id = $1", [A])).rows[0]).toMatchObject({
      auto_renew_status: false,
      status: "active",
    });

    const failed = transaction(A, {
      transactionId: "2000000000000003",
      expiresDate: Date.parse("2028-11-01T00:00:00Z"),
      signedDate: Date.parse("2028-11-01T01:00:00Z"),
    });
    const graceEnd = Date.parse("2028-11-17T00:00:00Z");
    const grace = await call(null, "POST", "/api/apple/notifications", {
      signedPayload: await notification("DID_FAIL_TO_RENEW", failed, {
        n: 5,
        subtype: "GRACE_PERIOD",
        renewal: { originalTransactionId: failed.originalTransactionId, gracePeriodExpiresDate: graceEnd, autoRenewStatus: 1 },
      }),
    });
    expect(grace.json).toMatchObject({ applied: true });
    expect((await db.query<{ status: string }>("select status from apple_subscriptions where user_id = $1", [A])).rows[0].status).toBe("grace");

    const graceOver = await call(null, "POST", "/api/apple/notifications", {
      signedPayload: await notification("GRACE_PERIOD_EXPIRED", transaction(A, {
        transactionId: "2000000000000004",
        expiresDate: Date.parse("2028-11-01T00:00:00Z"),
        signedDate: Date.parse("2028-11-17T01:00:00Z"),
      }), { n: 6 }),
    });
    expect(graceOver.json).toMatchObject({ applied: true });
    expect((await call("a", "GET", "/api/usage-summary")).json?.plan).toBe("free");

    const back = await call(null, "POST", "/api/apple/notifications", {
      signedPayload: await notification("DID_RENEW", transaction(A, {
        transactionId: "2000000000000005",
        expiresDate: Date.parse("2029-11-01T00:00:00Z"),
        signedDate: Date.parse("2028-11-20T00:00:00Z"),
      }), { n: 7 }),
    });
    expect(back.json).toMatchObject({ applied: true });
    expect((await call("a", "GET", "/api/usage-summary")).json?.plan).toBe("pro");

    const refund = await call(null, "POST", "/api/apple/notifications", {
      signedPayload: await notification("REFUND", transaction(A, {
        transactionId: "2000000000000006",
        expiresDate: Date.parse("2029-11-01T00:00:00Z"),
        revocationDate: Date.parse("2028-12-01T00:00:00Z"),
        signedDate: Date.parse("2028-12-01T00:00:00Z"),
      }), { n: 8 }),
    });
    expect(refund.json).toMatchObject({ applied: true });
    expect((await call("a", "GET", "/api/subscription")).json?.isPro).toBe(false);
    expect((await call("a", "GET", "/api/activity")).json?.rows).toEqual([]);

    const revoke = await call(null, "POST", "/api/apple/notifications", {
      signedPayload: await notification("SUBSCRIBED", transaction(B, {
        originalTransactionId: "4000000000000004",
        transactionId: "4000000000000004",
        productId: "cz.martinpohl.tokeny.pro.monthly",
        bundleId: "cz.martinpohl.tokeny.mac",
        signedDate: Date.parse("2026-11-16T10:00:00Z"),
      }), { n: 9 }),
    });
    expect(revoke.status).toBe(200);
    expect((await call("b", "GET", "/api/usage-summary")).json?.plan).toBe("pro");
    const revoked = await call(null, "POST", "/api/apple/notifications", {
      signedPayload: await notification("REVOKE", transaction(B, {
        originalTransactionId: "4000000000000004",
        transactionId: "4000000000000005",
        productId: "cz.martinpohl.tokeny.pro.monthly",
        bundleId: "cz.martinpohl.tokeny.mac",
        revocationDate: Date.parse("2026-11-20T00:00:00Z"),
        signedDate: Date.parse("2026-11-20T00:00:00Z"),
      }), { n: 10 }),
    });
    expect(revoked.json).toMatchObject({ applied: true });
    expect((await call("b", "GET", "/api/usage-summary")).json?.plan).toBe("free");
  });

  it("acknowledges an Apple TEST notification", async () => {
    const signedPayload = await sign({
      notificationType: "TEST",
      notificationUUID: "11111111-1111-4111-8111-111111111111",
      data: { bundleId: "cz.martinpohl.tokeny", environment: "Sandbox" },
      version: "2.0",
      signedDate: Date.parse("2026-11-16T00:00:00Z"),
    });
    expect((await call(null, "POST", "/api/apple/notifications", { signedPayload })).json).toMatchObject({ ok: true, applied: false });
  });
});
