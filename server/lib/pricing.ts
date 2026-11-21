// Web price test. Pure: no database, no Stripe SDK. Amounts live in src/config/pricing.ts;
// this file only decides the variant and which Stripe price id checkout should use.
import { createHash, randomUUID } from "node:crypto";

export type PricingVariant = "control" | "b";
export type PricingEventName = "view_paywall" | "start_checkout" | "subscribed";

export const PRICING_VARIANTS = ["control", "b"] as const;
export const PRICING_EVENTS = ["view_paywall", "start_checkout", "subscribed"] as const;

/** Stable across deploys. Changing it would reassign everyone. */
export const PRICING_HASH_PREFIX = "tokeny-pricing-v1\0";

export const PRICING_ANON_COOKIE = "tokeny_anon";
export const PRICING_ANON_MAX_AGE = 60 * 60 * 24 * 400;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface PriceEnv {
  STRIPE_PRICE_MONTHLY?: string;
  STRIPE_PRICE_YEARLY?: string;
  STRIPE_PRICE_MONTHLY_B?: string;
  STRIPE_PRICE_YEARLY_B?: string;
  [key: string]: string | undefined;
}

/** Both variant prices must be set. One of them missing keeps every visitor on control. */
export function experimentEnabled(env: PriceEnv): boolean {
  return Boolean(env.STRIPE_PRICE_MONTHLY_B && env.STRIPE_PRICE_YEARLY_B);
}

export function priceIdFor(variant: PricingVariant, interval: "month" | "year", env: PriceEnv): string | null {
  const useB = variant === "b" && experimentEnabled(env);
  const id = interval === "month"
    ? (useB ? env.STRIPE_PRICE_MONTHLY_B : env.STRIPE_PRICE_MONTHLY)
    : (useB ? env.STRIPE_PRICE_YEARLY_B : env.STRIPE_PRICE_YEARLY);
  return id || null;
}

export function intervalForPrice(priceId: string | null | undefined, env: PriceEnv): "month" | "year" | null {
  if (!priceId) return null;
  if (priceId === env.STRIPE_PRICE_MONTHLY || (env.STRIPE_PRICE_MONTHLY_B && priceId === env.STRIPE_PRICE_MONTHLY_B)) return "month";
  if (priceId === env.STRIPE_PRICE_YEARLY || (env.STRIPE_PRICE_YEARLY_B && priceId === env.STRIPE_PRICE_YEARLY_B)) return "year";
  return null;
}

/**
 * First byte of SHA-256(prefix + subject). 0–127 control, 128–255 b. The split is exactly half
 * of the byte values, and the same subject always lands on the same side.
 */
export function pricingVariantFor(subject: string): PricingVariant {
  const byte = createHash("sha256").update(`${PRICING_HASH_PREFIX}${subject}`).digest()[0];
  return byte < 128 ? "control" : "b";
}

export function newAnonId(): string {
  return randomUUID();
}

/**
 * Experiment off → control, and nothing is stored by the caller.
 * A stored variant wins. Otherwise a signed-in user keeps the variant their browser already
 * showed (the anon cookie) when that cookie arrived with the request; a first request with no
 * cookie uses the user id. Logged-out visitors use the anon id.
 */
export function assignedVariant(input: {
  experiment: boolean;
  stored: PricingVariant | null;
  userId: string | null;
  anonId: string;
  anonExisted: boolean;
}): PricingVariant {
  if (!input.experiment) return "control";
  if (input.stored === "control" || input.stored === "b") return input.stored;
  if (input.userId) return pricingVariantFor(input.anonExisted ? input.anonId : input.userId);
  return pricingVariantFor(input.anonId);
}

export function pricingVariantFromMetadata(metadata: { pricing_variant?: string | null } | null | undefined): PricingVariant | null {
  const variant = metadata?.pricing_variant;
  return variant === "control" || variant === "b" ? variant : null;
}

/** A paid or trial subscription counts. past_due and canceled do not. */
export function countsAsSubscribed(status: string, variant: PricingVariant | null): variant is PricingVariant {
  return (status === "active" || status === "trialing") && (variant === "control" || variant === "b");
}

export function isPricingAdmin(email: string | null | undefined, raw: string | null | undefined): boolean {
  if (!email || !raw) return false;
  const want = email.trim().toLowerCase();
  if (!want) return false;
  return raw.split(",").some((part) => part.trim().toLowerCase() === want);
}

export function readCookie(header: string | null | undefined, name: string): string | null {
  if (!header) return null;
  for (const part of header.split(";")) {
    const eq = part.indexOf("=");
    if (eq < 0) continue;
    if (part.slice(0, eq).trim() !== name) continue;
    const raw = part.slice(eq + 1).trim();
    try {
      return decodeURIComponent(raw);
    } catch {
      return raw;
    }
  }
  return null;
}

export function readAnonId(cookieHeader: string | null | undefined): string | null {
  const value = readCookie(cookieHeader, PRICING_ANON_COOKIE);
  return value && UUID_RE.test(value) ? value.toLowerCase() : null;
}

export function anonCookieHeader(id: string, secure: boolean): string {
  const parts = [
    `${PRICING_ANON_COOKIE}=${id}`,
    "Path=/",
    "HttpOnly",
    "SameSite=Lax",
    `Max-Age=${PRICING_ANON_MAX_AGE}`,
  ];
  if (secure) parts.push("Secure");
  return parts.join("; ");
}

export function requestIsHttps(url: string, forwardedProto: string | null | undefined): boolean {
  const forwarded = forwardedProto?.split(",")[0]?.trim();
  if (forwarded) return forwarded === "https";
  try {
    return new URL(url).protocol === "https:";
  } catch {
    return false;
  }
}

export interface PricingCountRow {
  variant: string;
  event: string;
  n: number;
}

export interface VariantSummary {
  view_paywall: number;
  start_checkout: number;
  subscribed: number;
  /** start_checkout / view_paywall. Null when nobody has seen the price. */
  checkoutRate: number | null;
  /** subscribed / view_paywall. Null when nobody has seen the price. */
  subscribeRate: number | null;
}

export function summarizePricingEvents(rows: readonly PricingCountRow[]): Record<PricingVariant, VariantSummary> {
  const blank = (): VariantSummary => ({
    view_paywall: 0,
    start_checkout: 0,
    subscribed: 0,
    checkoutRate: null,
    subscribeRate: null,
  });
  const out: Record<PricingVariant, VariantSummary> = { control: blank(), b: blank() };
  for (const row of rows) {
    if (row.variant !== "control" && row.variant !== "b") continue;
    if (row.event !== "view_paywall" && row.event !== "start_checkout" && row.event !== "subscribed") continue;
    out[row.variant][row.event] = Number(row.n) || 0;
  }
  for (const variant of PRICING_VARIANTS) {
    const summary = out[variant];
    summary.checkoutRate = summary.view_paywall > 0 ? summary.start_checkout / summary.view_paywall : null;
    summary.subscribeRate = summary.view_paywall > 0 ? summary.subscribed / summary.view_paywall : null;
  }
  return out;
}
