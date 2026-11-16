// Pure App Store entitlement rules (no I/O). The Swift twin of the account token is
// apple/TokenyKit/Sources/TokenyCore/AppAccountToken.swift. Keep the namespace identical.
// Whether a stored row grants Pro is isAppleEntitled() in plan.ts, matched by public.is_pro(uuid).
import { createHash } from "node:crypto";

/**
 * RFC 4122 namespace for Tokeny App Store account tokens (UUID version 5).
 * appAccountToken = UUIDv5(namespace, canonical lowercase Tokeny user id).
 * Do not change: existing transactions are bound to tokens from this namespace.
 * Documented in docs/apple-iap.md.
 */
export const APP_ACCOUNT_TOKEN_NAMESPACE = "b7e1c4a2-5d38-4f0e-9c61-2a8e6f0d4b93";

/** iOS app, and the Mac menu-bar app (its own bundle id; same subscription products). */
export const APPLE_BUNDLE_IDS = ["cz.martinpohl.tokeny", "cz.martinpohl.tokeny.mac"] as const;

/** apple/TokenyKit/Sources/TokenyCore/ProSubscription.swift */
export const APPLE_PRODUCT_IDS = [
  "cz.martinpohl.tokeny.pro.monthly",
  "cz.martinpohl.tokeny.pro.yearly",
] as const;

export const APPLE_ENVIRONMENTS = ["Production", "Sandbox", "Xcode"] as const;

export const APPLE_SUB_STATUSES = ["active", "expired", "revoked", "refunded", "grace", "billing_retry"] as const;
export type AppleSubStatus = (typeof APPLE_SUB_STATUSES)[number];

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

/** UUID version 5 (RFC 4122), lowercase. `namespace` is a UUID, `name` is an exact UTF-8 string. */
export function uuidV5(namespace: string, name: string): string {
  const ns = namespace.trim().toLowerCase();
  if (!UUID_RE.test(ns)) throw new Error("namespace must be a UUID");
  const hash = createHash("sha1").update(Buffer.from(ns.replace(/-/g, ""), "hex")).update(name, "utf8").digest();
  const bytes = Buffer.from(hash.subarray(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/**
 * App Store `appAccountToken` for a Tokeny user.
 * The user id is already a UUID; the token is UUIDv5 of its canonical lowercase form, so the
 * same account always presents the same token and a notification can be matched back to the user.
 * Returns null when `userId` is not a UUID.
 */
export function appAccountTokenForUser(userId: string): string | null {
  const id = userId.trim().toLowerCase();
  if (!UUID_RE.test(id)) return null;
  return uuidV5(APP_ACCOUNT_TOKEN_NAMESPACE, id);
}

export type ClaimError =
  | "bundle_id"
  | "product_id"
  | "environment"
  | "app_account_token"
  | "expires"
  | "signed_date"
  | "transaction_id"
  | "type";

export interface AppleTransactionClaims {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  environment: (typeof APPLE_ENVIRONMENTS)[number];
  /** Lowercase UUID. */
  appAccountToken: string;
  purchaseDateMs: number | null;
  expiresDateMs: number;
  revocationDateMs: number | null;
  signedDateMs: number;
  revocationReason: number | null;
}

export interface AppleRenewalClaims {
  autoRenewStatus: boolean | null;
  gracePeriodExpiresDateMs: number | null;
  originalTransactionId: string | null;
}

export interface AppleNotificationClaims {
  notificationType: string;
  subtype: string | null;
  notificationUUID: string | null;
  bundleId: string | null;
  environment: string | null;
  /** App Store data.status: 1 active, 2 expired, 3 billing retry, 4 grace, 5 revoked. */
  status: number | null;
  signedTransactionInfo: string | null;
  signedRenewalInfo: string | null;
}

export function readTransactionClaims(
  payload: Record<string, unknown>,
): { ok: true; tx: AppleTransactionClaims } | { ok: false; error: ClaimError } {
  const bundleId = str(payload.bundleId);
  if (!bundleId || !(APPLE_BUNDLE_IDS as readonly string[]).includes(bundleId)) return { ok: false, error: "bundle_id" };
  const productId = str(payload.productId);
  if (!productId || !(APPLE_PRODUCT_IDS as readonly string[]).includes(productId)) return { ok: false, error: "product_id" };
  const environment = str(payload.environment);
  if (!environment || !(APPLE_ENVIRONMENTS as readonly string[]).includes(environment)) return { ok: false, error: "environment" };
  const appAccountToken = str(payload.appAccountToken)?.toLowerCase() ?? "";
  if (!UUID_RE.test(appAccountToken)) return { ok: false, error: "app_account_token" };
  if (str(payload.type) !== "Auto-Renewable Subscription") return { ok: false, error: "type" };
  const transactionId = str(payload.transactionId);
  const originalTransactionId = str(payload.originalTransactionId);
  if (!isStoreId(transactionId) || !isStoreId(originalTransactionId)) return { ok: false, error: "transaction_id" };
  const expiresDateMs = num(payload.expiresDate);
  const signedDateMs = num(payload.signedDate);
  if (expiresDateMs == null) return { ok: false, error: "expires" };
  if (signedDateMs == null) return { ok: false, error: "signed_date" };
  return {
    ok: true,
    tx: {
      transactionId: transactionId!,
      originalTransactionId: originalTransactionId!,
      bundleId,
      productId,
      environment: environment as AppleTransactionClaims["environment"],
      appAccountToken,
      purchaseDateMs: num(payload.purchaseDate),
      expiresDateMs,
      revocationDateMs: num(payload.revocationDate),
      signedDateMs,
      revocationReason: num(payload.revocationReason),
    },
  };
}

export function readRenewalClaims(payload: Record<string, unknown>): AppleRenewalClaims {
  const status = num(payload.autoRenewStatus);
  return {
    autoRenewStatus: status === 1 ? true : status === 0 ? false : null,
    gracePeriodExpiresDateMs: num(payload.gracePeriodExpiresDate),
    originalTransactionId: str(payload.originalTransactionId),
  };
}

export function readNotification(payload: Record<string, unknown>): AppleNotificationClaims | null {
  const notificationType = str(payload.notificationType);
  if (!notificationType || notificationType.length > 64) return null;
  const data = payload.data && typeof payload.data === "object" && !Array.isArray(payload.data)
    ? (payload.data as Record<string, unknown>)
    : {};
  const subtype = str(payload.subtype);
  return {
    notificationType,
    subtype: subtype && subtype.length <= 64 ? subtype : null,
    notificationUUID: str(payload.notificationUUID),
    bundleId: str(data.bundleId),
    environment: str(data.environment),
    status: num(data.status),
    signedTransactionInfo: str(data.signedTransactionInfo),
    signedRenewalInfo: str(data.signedRenewalInfo),
  };
}

export function decideAppleStatus(input: {
  notificationType: string | null;
  subtype: string | null;
  dataStatus: number | null;
  expiresAtMs: number | null;
  revocationAtMs: number | null;
  graceExpiresAtMs: number | null;
  nowMs: number;
}): AppleSubStatus {
  if (input.revocationAtMs != null || input.notificationType === "REVOKE") {
    return input.notificationType === "REFUND" ? "refunded" : "revoked";
  }
  switch (input.notificationType) {
    case "EXPIRED":
    case "GRACE_PERIOD_EXPIRED":
      return "expired";
    case "REFUND":
      return "refunded";
    case "DID_FAIL_TO_RENEW": {
      const wantsGrace = input.subtype === "GRACE_PERIOD" || input.dataStatus === 4;
      if (wantsGrace && input.graceExpiresAtMs != null && input.graceExpiresAtMs > input.nowMs) return "grace";
      return "billing_retry";
    }
    default:
      if (input.expiresAtMs == null || input.expiresAtMs <= input.nowMs) return "expired";
      return "active";
  }
}

export interface AppleSubscriptionWrite {
  originalTransactionId: string;
  productId: string;
  bundleId: string;
  environment: string;
  status: AppleSubStatus;
  appAccountToken: string;
  latestTransactionId: string;
  purchaseDate: string | null;
  expiresAt: string | null;
  revocationDate: string | null;
  graceExpiresAt: string | null;
  autoRenewStatus: boolean | null;
  lastNotificationType: string | null;
  signedDate: string;
}

export function subscriptionFromClaims(
  tx: AppleTransactionClaims,
  note: {
    notificationType: string | null;
    subtype: string | null;
    dataStatus: number | null;
    graceExpiresAtMs: number | null;
    autoRenewStatus: boolean | null;
  },
  now: Date,
): AppleSubscriptionWrite {
  const status = decideAppleStatus({
    notificationType: note.notificationType,
    subtype: note.subtype,
    dataStatus: note.dataStatus,
    expiresAtMs: tx.expiresDateMs,
    revocationAtMs: tx.revocationDateMs,
    graceExpiresAtMs: note.graceExpiresAtMs,
    nowMs: now.getTime(),
  });
  const revocationMs = tx.revocationDateMs ?? (status === "refunded" || status === "revoked" ? tx.signedDateMs : null);
  return {
    originalTransactionId: tx.originalTransactionId,
    productId: tx.productId,
    bundleId: tx.bundleId,
    environment: tx.environment,
    status,
    appAccountToken: tx.appAccountToken,
    latestTransactionId: tx.transactionId,
    purchaseDate: msToIso(tx.purchaseDateMs),
    expiresAt: msToIso(tx.expiresDateMs),
    revocationDate: msToIso(revocationMs),
    graceExpiresAt: status === "grace" ? msToIso(note.graceExpiresAtMs) : null,
    autoRenewStatus: note.autoRenewStatus,
    lastNotificationType: note.notificationType,
    signedDate: new Date(tx.signedDateMs).toISOString(),
  };
}

export function msToIso(ms: number | null): string | null {
  if (ms == null) return null;
  return new Date(ms).toISOString();
}

function str(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function num(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  return value;
}

function isStoreId(value: string | null): value is string {
  return !!value && value.length <= 128 && /^[A-Za-z0-9._-]+$/.test(value);
}
