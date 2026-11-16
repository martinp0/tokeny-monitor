// App Store Pro: the signed-in app posts StoreKit 2 JWS, and Apple posts Server Notifications V2.
// Both are verified locally (server/lib/apple-jws.ts). Neither call needs an App Store Connect API key.
import type { Db } from "./db.js";
import * as repo from "./repo.js";
import { verifyAppleJws, AppleJwsError, type AppleVerifyConfig } from "./lib/apple-jws.js";
import {
  appAccountTokenForUser,
  readNotification,
  readRenewalClaims,
  readTransactionClaims,
  subscriptionFromClaims,
  type AppleNotificationClaims,
  type AppleRenewalClaims,
  type AppleTransactionClaims,
} from "./lib/apple-entitlement.js";

export interface AppleResult {
  status: number;
  body: Record<string, unknown>;
}

const MAX_TRANSACTIONS = 8;
const MAX_JWS_CHARS = 20_000;

export async function postAppleTransactions(
  db: Db,
  callerId: string,
  body: unknown,
  roots: readonly string[],
  now = new Date(),
): Promise<AppleResult> {
  const userId = callerId.trim().toLowerCase();
  const expected = appAccountTokenForUser(userId);
  if (!expected) return { status: 400, body: { error: "invalid_user" } };

  const signed = readSignedList(body);
  if (!signed) return { status: 400, body: { error: "invalid_transaction" } };

  const writes = [];
  for (const jws of signed) {
    const tx = await verifiedTransaction(jws, roots, now);
    if (!tx.ok) return { status: 400, body: { error: "invalid_transaction" } };
    if (tx.tx.appAccountToken !== expected) return { status: 403, body: { error: "app_account_token_mismatch" } };
    const owner = await repo.appleSubscriptionOwner(db, tx.tx.originalTransactionId);
    if (owner && owner !== userId) return { status: 409, body: { error: "apple_transaction_in_use" } };
    writes.push(subscriptionFromClaims(tx.tx, {
      notificationType: null,
      subtype: null,
      dataStatus: null,
      graceExpiresAtMs: null,
      autoRenewStatus: null,
    }, now));
  }

  let accepted = 0;
  for (const row of writes) {
    const result = await repo.upsertAppleSubscription(db, userId, row);
    if (result === "conflict") return { status: 409, body: { error: "apple_transaction_in_use" } };
    accepted += 1;
  }
  return { status: 200, body: { isPro: await repo.isPro(db, userId), accepted } };
}

/**
 * App Store Server Notifications V2. Unauthenticated; the signed payload is the credential.
 * Unknown accounts are acknowledged (Apple retries non-200) and not stored.
 * A transaction already bound to another user is left where it is.
 */
export async function postAppleNotification(
  db: Db,
  body: unknown,
  roots: readonly string[],
  now = new Date(),
): Promise<AppleResult> {
  const signedPayload = body && typeof body === "object" && !Array.isArray(body)
    ? (body as { signedPayload?: unknown }).signedPayload
    : null;
  if (typeof signedPayload !== "string" || signedPayload.length === 0 || signedPayload.length > 80_000) {
    return { status: 400, body: { error: "invalid_notification" } };
  }

  let outer: Record<string, unknown>;
  try {
    outer = await verifyAppleJws(signedPayload, { roots, now });
  } catch (e) {
    if (e instanceof AppleJwsError) return { status: 400, body: { error: "invalid_notification" } };
    throw e;
  }
  const note = readNotification(outer);
  if (!note) return { status: 400, body: { error: "invalid_notification" } };
  if (note.bundleId && note.bundleId !== "cz.martinpohl.tokeny" && note.bundleId !== "cz.martinpohl.tokeny.mac") {
    return { status: 400, body: { error: "invalid_notification" } };
  }
  if (note.notificationType === "TEST" || !note.signedTransactionInfo) {
    return { status: 200, body: { ok: true, applied: false } };
  }

  const tx = await verifiedTransaction(note.signedTransactionInfo, roots, now);
  if (!tx.ok) return { status: 400, body: { error: "invalid_notification" } };
  if (note.bundleId && note.bundleId !== tx.tx.bundleId) return { status: 400, body: { error: "invalid_notification" } };

  let renewal: AppleRenewalClaims | null = null;
  if (note.signedRenewalInfo) {
    const parsed = await verifiedRenewal(note.signedRenewalInfo, roots, now);
    if (!parsed) return { status: 400, body: { error: "invalid_notification" } };
    if (parsed.originalTransactionId && parsed.originalTransactionId !== tx.tx.originalTransactionId) {
      return { status: 400, body: { error: "invalid_notification" } };
    }
    renewal = parsed;
  }

  const userId = await repo.userIdByAppAccountToken(db, tx.tx.appAccountToken);
  if (!userId) return { status: 200, body: { ok: true, applied: false } };
  if (appAccountTokenForUser(userId) !== tx.tx.appAccountToken) {
    return { status: 200, body: { ok: true, applied: false } };
  }

  const write = subscriptionFromClaims(tx.tx, {
    notificationType: note.notificationType,
    subtype: note.subtype,
    dataStatus: note.status,
    graceExpiresAtMs: renewal?.gracePeriodExpiresDateMs ?? null,
    autoRenewStatus: autoRenewFrom(note, renewal),
  }, now);
  const result = await repo.upsertAppleSubscription(db, userId, write);
  if (result === "conflict") return { status: 200, body: { ok: true, applied: false } };
  return { status: 200, body: { ok: true, applied: result === "applied" } };
}

function readSignedList(body: unknown): string[] | null {
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  const list = (body as { signedTransactions?: unknown }).signedTransactions;
  if (!Array.isArray(list) || list.length === 0 || list.length > MAX_TRANSACTIONS) return null;
  if (!list.every((item) => typeof item === "string" && item.length > 0 && item.length <= MAX_JWS_CHARS)) return null;
  return list;
}

async function verifiedTransaction(
  jws: string,
  roots: readonly string[],
  now: Date,
): Promise<{ ok: true; tx: AppleTransactionClaims } | { ok: false }> {
  try {
    const payload = await verifyAppleJws(jws, verifyConfig(roots, now));
    const claims = readTransactionClaims(payload);
    return claims.ok ? claims : { ok: false };
  } catch (e) {
    if (e instanceof AppleJwsError) return { ok: false };
    throw e;
  }
}

async function verifiedRenewal(jws: string, roots: readonly string[], now: Date): Promise<AppleRenewalClaims | null> {
  try {
    const payload = await verifyAppleJws(jws, verifyConfig(roots, now));
    return readRenewalClaims(payload);
  } catch (e) {
    if (e instanceof AppleJwsError) return null;
    throw e;
  }
}

function autoRenewFrom(note: AppleNotificationClaims, renewal: AppleRenewalClaims | null): boolean | null {
  if (renewal?.autoRenewStatus != null) return renewal.autoRenewStatus;
  if (note.subtype === "AUTO_RENEW_ENABLED") return true;
  if (note.subtype === "AUTO_RENEW_DISABLED") return false;
  return null;
}

function verifyConfig(roots: readonly string[], now: Date): AppleVerifyConfig {
  return { roots, now };
}
