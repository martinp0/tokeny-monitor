// @vitest-environment node
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { PGlite } from "@electric-sql/pglite";
import { PRICING_VARIANTS, yearlySavingMonths } from "@/config/pricing";
import type { Db } from "../../server/db";
import { createApp } from "../../server/app";
import {
  PRICING_ANON_COOKIE,
  PRICING_HASH_PREFIX,
  assignedVariant,
  experimentEnabled,
  intervalForPrice,
  isPricingAdmin,
  priceIdFor,
  pricingVariantFor,
  readAnonId,
  summarizePricingEvents,
} from "../../server/lib/pricing";

const A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const users: Record<string, { id: string; email: string; name: string }> = {
  a: { id: A, email: "owner@example.test", name: "Owner" },
};

function asDb(p: PGlite): Db {
  return {
    async query(text, params) {
      const r = await p.query(text, params as unknown[]);
      return { rows: r.rows as never[], rowCount: r.affectedRows ?? r.rows.length };
    },
  };
}

describe("price variants", () => {
  it("keeps control at 99/990 and B at 79/790, both with two months free", () => {
    expect(PRICING_VARIANTS.control).toEqual({ monthly: 99, yearly: 990 });
    expect(PRICING_VARIANTS.b).toEqual({ monthly: 79, yearly: 790 });
    expect(yearlySavingMonths("control")).toBe(2);
    expect(yearlySavingMonths("b")).toBe(2);
    const storekit = readFileSync(path.resolve(__dirname, "../../apple/Config/TokenyPro.storekit"), "utf8");
    expect(storekit).toContain('"displayPrice" : "99"');
    expect(storekit).toContain('"displayPrice" : "990"');
    expect(storekit).not.toContain('"displayPrice" : "49"');
    expect(storekit).not.toContain('"displayPrice" : "399"');
  });

  it("assigns a stable half split from the first hash byte", () => {
    const subject = "11111111-1111-4111-8111-111111111111";
    const byte = createHash("sha256").update(`${PRICING_HASH_PREFIX}${subject}`).digest()[0];
    expect(pricingVariantFor(subject)).toBe(byte < 128 ? "control" : "b");
    expect(pricingVariantFor(subject)).toBe(pricingVariantFor(subject));
    let control = 0;
    for (let i = 0; i < 256; i++) {
      if (pricingVariantFor(`user-${i}`).startsWith("control")) control += 1;
    }
    expect(control).toBeGreaterThan(90);
    expect(control).toBeLessThan(166);
  });

  it("stays on control unless both B price ids exist, and checkout uses the stored variant", () => {
    const env = { STRIPE_PRICE_MONTHLY: "price_m", STRIPE_PRICE_YEARLY: "price_y" };
    expect(experimentEnabled(env)).toBe(false);
    expect(experimentEnabled({ ...env, STRIPE_PRICE_MONTHLY_B: "price_bm" })).toBe(false);
    const on = { ...env, STRIPE_PRICE_MONTHLY_B: "price_bm", STRIPE_PRICE_YEARLY_B: "price_by" };
    expect(experimentEnabled(on)).toBe(true);
    expect(priceIdFor("b", "month", env)).toBe("price_m");
    expect(priceIdFor("b", "year", on)).toBe("price_by");
    expect(priceIdFor("control", "month", on)).toBe("price_m");
    expect(intervalForPrice("price_by", on)).toBe("year");
    expect(intervalForPrice("price_bm", on)).toBe("month");
    expect(intervalForPrice("price_other", on)).toBeNull();

    const anon = "22222222-2222-4222-8222-222222222222";
    expect(assignedVariant({ experiment: false, stored: "b", userId: A, anonId: anon, anonExisted: true })).toBe("control");
    expect(assignedVariant({ experiment: true, stored: "b", userId: A, anonId: anon, anonExisted: false })).toBe("b");
    expect(assignedVariant({ experiment: true, stored: null, userId: null, anonId: anon, anonExisted: true })).toBe(pricingVariantFor(anon));
    expect(assignedVariant({ experiment: true, stored: null, userId: A, anonId: anon, anonExisted: true })).toBe(pricingVariantFor(anon));
    expect(assignedVariant({ experiment: true, stored: null, userId: A, anonId: anon, anonExisted: false })).toBe(pricingVariantFor(A));
  });

  it("recognises the owner e-mail and a uuid cookie only", () => {
    expect(isPricingAdmin("Owner@Example.test", " owner@example.test , other@example.test ")).toBe(true);
    expect(isPricingAdmin("a@example.test", "")).toBe(false);
    expect(isPricingAdmin(null, "a@example.test")).toBe(false);
    expect(readAnonId("other=1; tokeny_anon=not-a-uuid")).toBeNull();
    expect(readAnonId(`${PRICING_ANON_COOKIE}=${A}`)).toBe(A);
  });

  it("summarizes conversion per variant", () => {
    const summary = summarizePricingEvents([
      { variant: "control", event: "view_paywall", n: 4 },
      { variant: "control", event: "start_checkout", n: 2 },
      { variant: "control", event: "subscribed", n: 1 },
      { variant: "b", event: "view_paywall", n: 2 },
    ]);
    expect(summary.control).toMatchObject({ view_paywall: 4, start_checkout: 2, subscribed: 1, checkoutRate: 0.5, subscribeRate: 0.25 });
    expect(summary.b).toMatchObject({ view_paywall: 2, start_checkout: 0, subscribed: 0, checkoutRate: 0, subscribeRate: 0 });
  });
});

describe("GET /api/pricing", () => {
  let db: Db;
  let app: ReturnType<typeof createApp>;
  const previous: Record<string, string | undefined> = {};

  beforeAll(async () => {
    for (const key of ["STRIPE_PRICE_MONTHLY_B", "STRIPE_PRICE_YEARLY_B", "PRICING_ADMIN_EMAIL"]) {
      previous[key] = process.env[key];
    }
    process.env.STRIPE_PRICE_MONTHLY_B = "price_b_month";
    process.env.STRIPE_PRICE_YEARLY_B = "price_b_year";
    process.env.PRICING_ADMIN_EMAIL = "owner@example.test";
    const pg = new PGlite();
    await pg.exec(`
      create schema neon_auth;
      create table neon_auth."user" (id uuid primary key, name text, email text, "emailVerified" boolean default false,
        image text, "createdAt" timestamptz default now(), "updatedAt" timestamptz default now());
    `);
    const schema = readFileSync(path.resolve(__dirname, "../../db/schema.sql"), "utf8").replace(/CREATE EXTENSION[^;]*;/i, "");
    await pg.exec(schema);
    await pg.query(`insert into neon_auth."user" (id, name, email) values ($1, $2, $3)`, [A, "Owner", "owner@example.test"]);
    db = asDb(pg);
    app = createApp({
      db: () => db,
      sessionUser: async (req) => {
        const u = users[req.headers.get("x-test-user") ?? ""];
        return u ? { ...u, image: null, emailVerified: true } : null;
      },
    });
  }, 60_000);

  afterAll(() => {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });

  async function hit(path: string, init: RequestInit = {}) {
    const res = await app.fetch(new Request(`https://tokeny.test${path}`, init));
    const json = await res.json() as Record<string, unknown>;
    return { status: res.status, json, cookie: res.headers.get("set-cookie") };
  }

  it("keeps an anonymous visitor on the same variant and the same cookie", async () => {
    const first = await hit("/api/pricing");
    expect(first.status).toBe(200);
    expect(first.json.experiment).toBe(true);
    expect(["control", "b"]).toContain(first.json.variant);
    const id = first.cookie?.match(/tokeny_anon=([0-9a-f-]+)/)?.[1];
    expect(id).toBeTruthy();
    const again = await hit("/api/pricing", { headers: { cookie: `${PRICING_ANON_COOKIE}=${id}` } });
    expect(again.json.variant).toBe(first.json.variant);
    expect(again.cookie).toContain(id!);
    const viewed = await hit("/api/pricing/event", {
      method: "POST",
      headers: { cookie: `${PRICING_ANON_COOKIE}=${id}`, "content-type": "application/json" },
      body: JSON.stringify({ event: "view_paywall", variant: "b" }),
    });
    expect(viewed.status).toBe(200);
    const rows = await db.query<{ variant: string; anon_id: string; user_id: string | null }>(
      "select variant, anon_id, user_id::text as user_id from pricing_events where anon_id = $1",
      [id],
    );
    expect(rows.rows).toEqual([{ variant: first.json.variant, anon_id: id, user_id: null }]);
  });

  it("stores the signed-in variant and the admin summary counts it", async () => {
    const anon = "33333333-3333-4333-8333-333333333333";
    const offer = await hit("/api/pricing", { headers: { "x-test-user": "a", cookie: `${PRICING_ANON_COOKIE}=${anon}` } });
    expect(offer.json.variant).toBe(pricingVariantFor(anon));
    const stored = await db.query<{ pricing_variant: string }>("select pricing_variant from profiles where user_id = $1", [A]);
    expect(stored.rows[0].pricing_variant).toBe(offer.json.variant);
    const stuck = await hit("/api/pricing", { headers: { "x-test-user": "a" } });
    expect(stuck.json.variant).toBe(offer.json.variant);

    await hit("/api/pricing/event", {
      method: "POST",
      headers: { "x-test-user": "a", cookie: `${PRICING_ANON_COOKIE}=${anon}`, "content-type": "application/json" },
      body: JSON.stringify({ event: "view_paywall" }),
    });
    const summary = await hit("/api/pricing/experiment", { headers: { "x-test-user": "a" } });
    expect(summary.status).toBe(200);
    const variants = summary.json.variants as Record<string, { view_paywall: number }>;
    const seen = variants.control.view_paywall + variants.b.view_paywall;
    expect(seen).toBeGreaterThan(0);
    expect((await hit("/api/pricing/experiment")).status).toBe(401);

    delete process.env.STRIPE_PRICE_MONTHLY_B;
    const off = await hit("/api/pricing", { headers: { "x-test-user": "a" } });
    expect(off.json).toEqual({ variant: "control", experiment: false });
    process.env.STRIPE_PRICE_MONTHLY_B = "price_b_month";
    const back = await hit("/api/pricing", { headers: { "x-test-user": "a" } });
    expect(back.json.variant).toBe(offer.json.variant);
  });
});
