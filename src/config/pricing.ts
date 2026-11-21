/**
 * Single source of truth for plan prices shown in the UI.
 * Landing, Settings, UpgradeModal and ProGate read the assigned variant from here.
 *
 * Control (canonical, also the iOS price and the terms): 99 Kč / month, 990 Kč / year.
 * Variant B (web only, 50/50 when both Stripe B price ids are set): 79 Kč / month, 790 Kč / year.
 * Yearly is two months free at either price. The 14-day trial is web checkout
 * (STRIPE_TRIAL_DAYS must be 14). Stripe price ids stay in the server env:
 * STRIPE_PRICE_MONTHLY / STRIPE_PRICE_YEARLY and, for B, STRIPE_PRICE_MONTHLY_B /
 * STRIPE_PRICE_YEARLY_B. If either B id is missing the experiment is off and everyone
 * sees control. Limits are enforced server-side (server/lib/plan.ts).
 *
 * Existing control prices on product Tokeny Pro (prod_VXDr0XHK7gteJO), account martinpohl.cz:
 *   monthly 99 Kč → price_1UW9Py6jFD9ux2ZIFyLZKM6k (lookup_key tokeny_pro_monthly)
 *   yearly  990 Kč → price_1UW9Pz6jFD9ux2ZIzt5tYuVw (lookup_key tokeny_pro_yearly)
 * Variant B prices are created by the owner; they are not in this file. See docs/pricing-experiment.md.
 */
import { FREE_LIMITS } from "@/lib/plan";

export const PRO_CHECKOUT_ENABLED = true;

/** Free trial for first-time subscribers (must match STRIPE_TRIAL_DAYS; 0 hides the copy). */
export const PRO_TRIAL_DAYS = 14;

export const PRICING_VARIANTS = {
  control: { monthly: 99, yearly: 990 },
  b: { monthly: 79, yearly: 790 },
} as const;

export type PricingVariant = keyof typeof PRICING_VARIANTS;

export const PRICING = {
  currency: "CZK",
  pro: PRICING_VARIANTS.control,
} as const;

export function pricesFor(variant: PricingVariant | null | undefined) {
  return variant === "b" ? PRICING_VARIANTS.b : PRICING_VARIANTS.control;
}

/** Two months free at the control price and at variant B (790/79 = 10). */
export function yearlySavingMonths(variant: PricingVariant = "control") {
  const prices = pricesFor(variant);
  return Math.round(12 - prices.yearly / prices.monthly);
}

export { FREE_LIMITS };

export type PlanId = "free" | "pro";
export type BillingInterval = "month" | "year";

/** i18n keys under `pricing.features.*` */
export const PLAN_FEATURES: Record<PlanId, string[]> = {
  free: ["dashboard", "oneProvider", "history30", "csvImport", "currency", "calculator", "aiAgent"],
  pro: [
    "everythingFree",
    "unlimitedProviders",
    "fullHistory",
    "autoSync",
    "budgetAlerts",
    "forecast",
    "exports",
    "sharing",
    "mcp",
  ],
};

export function formatCzk(amount: number, locale = "cs-CZ") {
  return new Intl.NumberFormat(locale, { style: "currency", currency: "CZK", maximumFractionDigits: 0 }).format(amount);
}

/** e.g. "99 Kč / měsíc" */
export function proMonthlyLabel(
  t: (k: string, o?: Record<string, unknown>) => string,
  locale?: string,
  variant: PricingVariant = "control",
) {
  return t("pricing.perMonth", { price: formatCzk(pricesFor(variant).monthly, locale) });
}

/** Two months free when paying yearly (control). */
export const YEARLY_SAVING_MONTHS = yearlySavingMonths("control");

/** Fill {{monthly}} / {{yearly}} in copy that states the Pro price. */
export function fillPriceCopy(text: string, prices: { monthly: number; yearly: number }) {
  return text.replace(/\{\{monthly\}\}/g, String(prices.monthly)).replace(/\{\{yearly\}\}/g, String(prices.yearly));
}
