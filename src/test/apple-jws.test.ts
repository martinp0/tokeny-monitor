import { readFileSync } from "node:fs";
import { X509Certificate } from "node:crypto";
import { describe, expect, it } from "vitest";
import { AppleJwsError, verifyAppleJws } from "../../server/lib/apple-jws";
import { APPLE_ROOT_CA_G3_PEM, productionAppleRoots } from "../../server/lib/apple-root-ca-g3";
import { appleServerApiConfigFrom } from "../../server/lib/apple-server-api";
import {
  APP_ACCOUNT_TOKEN_NAMESPACE,
  appAccountTokenForUser,
  decideAppleStatus,
  readTransactionClaims,
  uuidV5,
} from "../../server/lib/apple-entitlement";
import { isAppleEntitled, isProAccount } from "../../server/lib/plan";
import { foreignRootPem, testChain } from "./apple-jws-fixture";

const USER = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const NOW = new Date("2026-11-16T12:00:00Z");

function tx(over: Record<string, unknown> = {}) {
  return {
    transactionId: "2000000000000001",
    originalTransactionId: "2000000000000001",
    bundleId: "cz.martinpohl.tokeny",
    productId: "cz.martinpohl.tokeny.pro.monthly",
    purchaseDate: Date.parse("2026-11-01T00:00:00Z"),
    expiresDate: Date.parse("2026-12-01T00:00:00Z"),
    type: "Auto-Renewable Subscription",
    environment: "Sandbox",
    signedDate: Date.parse("2026-11-16T00:00:00Z"),
    appAccountToken: appAccountTokenForUser(USER),
    ...over,
  };
}

describe("app account token", () => {
  it("matches the RFC 4122 UUID v5 vector", () => {
    expect(uuidV5("6ba7b810-9dad-11d1-80b4-00c04fd430c8", "www.example.com")).toBe(
      "2ed6657d-e927-568b-95e1-2665a8aea6a2",
    );
  });

  it("is a lowercase UUID derived from the canonical user id", () => {
    const token = appAccountTokenForUser(`  ${USER.toUpperCase()}  `);
    expect(token).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(token).toBe(appAccountTokenForUser(USER));
    expect(token).not.toBe(USER);
    expect(appAccountTokenForUser("not-a-uuid")).toBeNull();
    expect(appAccountTokenForUser("")).toBeNull();
  });

  it("uses the namespace the Swift client documents", () => {
    const swift = readFileSync("apple/TokenyKit/Sources/TokenyCore/AppAccountToken.swift", "utf8");
    const swiftTest = readFileSync("apple/TokenyKit/Tests/TokenyCoreTests/AppAccountTokenTests.swift", "utf8");
    expect(swift).toContain(APP_ACCOUNT_TOKEN_NAMESPACE);
    expect(swiftTest).toContain(APP_ACCOUNT_TOKEN_NAMESPACE);
    expect(swiftTest).toContain("2ed6657d-e927-568b-95e1-2665a8aea6a2");
    const products = readFileSync("apple/TokenyKit/Sources/TokenyCore/ProSubscription.swift", "utf8");
    expect(products).toContain("cz.martinpohl.tokeny.pro.monthly");
    expect(products).toContain("cz.martinpohl.tokeny.pro.yearly");
  });
});

describe("StoreKit JWS", () => {
  it("pins Apple Root CA - G3 and does not take a root from the environment", () => {
    const cert = new X509Certificate(APPLE_ROOT_CA_G3_PEM);
    expect(cert.subject).toContain("Apple Root CA - G3");
    expect(cert.fingerprint256).toBe(
      "63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79",
    );
    expect(productionAppleRoots()).toEqual([APPLE_ROOT_CA_G3_PEM]);
    const source = readFileSync("server/lib/apple-jws.ts", "utf8") + readFileSync("server/lib/apple-root-ca-g3.ts", "utf8");
    expect(source).not.toMatch(/process\.env/);
  });

  it("accepts a fixture chain only when that root is injected", async () => {
    const chain = await testChain();
    const jws = await chain.sign(tx());
    const payload = await verifyAppleJws(jws, { roots: [chain.rootPem] });
    expect(readTransactionClaims(payload).ok).toBe(true);
    await expect(verifyAppleJws(jws, { roots: productionAppleRoots() })).rejects.toMatchObject({ code: "root" });
  });

  it("rejects a leaf without Apple's App Store OID, a foreign root, and a bad signature", async () => {
    const chain = await testChain();
    const payload = tx();
    await expect(verifyAppleJws(await chain.sign(payload, { omitOid: true }), { roots: [chain.rootPem] })).rejects.toMatchObject({
      code: "oid",
    });
    const foreign = await foreignRootPem();
    await expect(verifyAppleJws(await chain.sign(payload), { roots: [foreign] })).rejects.toBeInstanceOf(AppleJwsError);
    const jws = await chain.sign(payload);
    const [h, , s] = jws.split(".");
    await expect(verifyAppleJws(`${h}.${Buffer.from("{}").toString("base64url")}.${s}`, { roots: [chain.rootPem] })).rejects.toMatchObject({
      code: "signature",
    });
  });

  it("rejects the wrong bundle, product, environment and a missing account token", async () => {
    const chain = await testChain();
    const roots = [chain.rootPem];
    const bad = async (over: Record<string, unknown>) => readTransactionClaims(await verifyAppleJws(await chain.sign(tx(over)), { roots }));
    expect(await bad({ bundleId: "cz.martinpohl.tokeny.watchkitapp" })).toMatchObject({ ok: false, error: "bundle_id" });
    expect(await bad({ productId: "cz.martinpohl.tokeny.pro.lifetime" })).toMatchObject({ ok: false, error: "product_id" });
    expect(await bad({ environment: "Local" })).toMatchObject({ ok: false, error: "environment" });
    expect(await bad({ appAccountToken: "not-a-uuid" })).toMatchObject({ ok: false, error: "app_account_token" });
    expect(await bad({ type: "Consumable" })).toMatchObject({ ok: false, error: "type" });
    expect((await bad({ bundleId: "cz.martinpohl.tokeny.mac" })).ok).toBe(true);
  });
});

describe("entitlement decisions", () => {
  const future = Date.parse("2026-12-01T00:00:00Z");
  const past = Date.parse("2026-10-01T00:00:00Z");
  const base = {
    subtype: null,
    dataStatus: null,
    expiresAtMs: future,
    revocationAtMs: null as number | null,
    graceExpiresAtMs: null as number | null,
    nowMs: NOW.getTime(),
  };

  it("maps renewals, expiry, grace, refunds and revocations", () => {
    expect(decideAppleStatus({ ...base, notificationType: "DID_RENEW" })).toBe("active");
    expect(decideAppleStatus({ ...base, notificationType: null })).toBe("active");
    expect(decideAppleStatus({ ...base, notificationType: "EXPIRED" })).toBe("expired");
    expect(decideAppleStatus({ ...base, notificationType: "GRACE_PERIOD_EXPIRED" })).toBe("expired");
    expect(decideAppleStatus({ ...base, notificationType: "DID_FAIL_TO_RENEW", subtype: "GRACE_PERIOD", graceExpiresAtMs: future })).toBe("grace");
    expect(decideAppleStatus({ ...base, notificationType: "DID_FAIL_TO_RENEW" })).toBe("billing_retry");
    expect(decideAppleStatus({ ...base, notificationType: "REFUND" })).toBe("refunded");
    expect(decideAppleStatus({ ...base, notificationType: "REVOKE", revocationAtMs: past })).toBe("revoked");
    expect(decideAppleStatus({ ...base, notificationType: "DID_CHANGE_RENEWAL_STATUS" })).toBe("active");
    expect(decideAppleStatus({ ...base, notificationType: null, expiresAtMs: past })).toBe("expired");
  });

  it("grants Pro for an active or in-grace App Store row, including next to a free Stripe row", () => {
    const active = { status: "active", expires_at: "2026-12-01T00:00:00Z", revocation_date: null, grace_expires_at: null };
    expect(isAppleEntitled(active, NOW)).toBe(true);
    expect(isAppleEntitled({ ...active, expires_at: "2026-10-01T00:00:00Z" }, NOW)).toBe(false);
    expect(isAppleEntitled({ ...active, revocation_date: "2026-11-01T00:00:00Z" }, NOW)).toBe(false);
    expect(isAppleEntitled({ status: "billing_retry", expires_at: "2026-10-01T00:00:00Z", revocation_date: null, grace_expires_at: null }, NOW)).toBe(false);
    expect(isAppleEntitled({ status: "grace", expires_at: "2026-11-01T00:00:00Z", revocation_date: null, grace_expires_at: "2026-11-20T00:00:00Z" }, NOW)).toBe(true);
    expect(isAppleEntitled({ status: "refunded", expires_at: "2026-12-01T00:00:00Z", revocation_date: "2026-11-10T00:00:00Z", grace_expires_at: null }, NOW)).toBe(false);
    expect(isProAccount(null, [active], NOW)).toBe(true);
    expect(isProAccount({ status: "canceled", current_period_end: "2026-12-01T00:00:00Z" }, [active], NOW)).toBe(true);
    expect(isProAccount({ status: "active", current_period_end: "2026-12-01T00:00:00Z" }, [], NOW)).toBe(true);
    expect(isProAccount(null, [], NOW)).toBe(false);
  });
});

describe("optional App Store Server API key", () => {
  it("stays unset unless issuer, key id and a PEM are all present", () => {
    expect(appleServerApiConfigFrom({})).toBeNull();
    expect(appleServerApiConfigFrom({ APPLE_ISSUER_ID: "iss", APPLE_KEY_ID: "KEY" })).toBeNull();
    expect(appleServerApiConfigFrom({
      APPLE_ISSUER_ID: "iss",
      APPLE_KEY_ID: "KEY",
      APPLE_PRIVATE_KEY: "-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----",
    })).toMatchObject({ issuerId: "iss", keyId: "KEY" });
  });
});
