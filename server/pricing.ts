// Assigns the web price variant and remembers it. The amounts are in src/config/pricing.ts;
// checkout uses the Stripe price id for the variant this returns.
import type { Db } from "./db.js";
import * as repo from "./repo.js";
import {
  anonCookieHeader,
  assignedVariant,
  experimentEnabled,
  newAnonId,
  readAnonId,
  requestIsHttps,
  type PricingVariant,
} from "./lib/pricing.js";

export interface PricingUser {
  id: string;
  email: string | null;
}

export interface PricingOffer {
  variant: PricingVariant;
  experiment: boolean;
  anonId: string;
}

export function pricingCookie(anonId: string, url: string, forwardedProto: string | null | undefined): string {
  return anonCookieHeader(anonId, requestIsHttps(url, forwardedProto));
}

/**
 * Logged-out: hash of the anon cookie. Logged-in: the stored variant, or the anon cookie's
 * variant when this browser already had one (so the price they saw is the price checkout uses),
 * otherwise the hash of the user id. Experiment off always returns control and stores nothing.
 */
export async function resolvePricingOffer(db: Db, user: PricingUser | null, cookieHeader: string | null): Promise<PricingOffer> {
  const hadAnon = readAnonId(cookieHeader);
  const anonId = hadAnon ?? newAnonId();
  const experiment = experimentEnabled(process.env);
  const stored = experiment && user ? await repo.getPricingVariant(db, user.id) : null;
  let variant = assignedVariant({
    experiment,
    stored,
    userId: user?.id ?? null,
    anonId,
    anonExisted: !!hadAnon,
  });
  if (experiment && user && !stored) {
    await repo.setPricingVariant(db, user.id, variant);
    variant = (await repo.getPricingVariant(db, user.id)) ?? variant;
  }
  return { variant, experiment, anonId };
}
