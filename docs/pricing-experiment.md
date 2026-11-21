# Web price test

Control is the price everywhere else: **99 Kč / month**, **990 Kč / year** (two months free), **14-day trial** on web checkout. iOS sells that same pair and does not run this test. Variant B is web only: **79 Kč / month**, **790 Kč / year** (also two months free, same 14-day trial).

The amounts live in `src/config/pricing.ts`. Stripe price ids live in the server env. If `STRIPE_PRICE_MONTHLY_B` or `STRIPE_PRICE_YEARLY_B` is missing, the test is off and every visitor sees control. Checkout then uses the control price ids even if a variant was stored earlier.

## What you create in Stripe

Creating a price does not cost anything. Do this in the Stripe Dashboard (test mode first if you want a dry run, then live). Do not edit the prices current subscribers are already on.

Product: **Tokeny Pro** (`prod_VXDr0XHK7gteJO`).

Confirm the existing control prices are still 99 CZK monthly and 990 CZK yearly, then leave them alone:

| | Amount | Price id | Env |
|---|---|---|---|
| Monthly | 99 Kč | `price_1UW9Py6jFD9ux2ZIFyLZKM6k` | `STRIPE_PRICE_MONTHLY` |
| Yearly | 990 Kč | `price_1UW9Pz6jFD9ux2ZIzt5tYuVw` | `STRIPE_PRICE_YEARLY` |

Create two new recurring prices on that same product, currency **CZK**. In the Dashboard, type the crown amount. CZK is a two-decimal currency in Stripe (not on the zero-decimal list), so the API `unit_amount` is in haléře:

| | Type this | `unit_amount` | Interval | Suggested lookup key | Env |
|---|---|---|---|---|---|
| B monthly | 79.00 CZK | 7900 | month | `tokeny_pro_monthly_b` | `STRIPE_PRICE_MONTHLY_B` |
| B yearly | 790.00 CZK | 79000 | year | `tokeny_pro_yearly_b` | `STRIPE_PRICE_YEARLY_B` |

Match the tax behavior of the existing 99 / 990 prices. Prices are final; the seller is not a VAT payer. Do not put a trial on the Price. The 14 days are `trial_period_days` on the Checkout Session, from `STRIPE_TRIAL_DAYS`.

Copy the new `price_…` ids into Vercel Production (and Preview, if you want the test there):

- `STRIPE_PRICE_MONTHLY_B`
- `STRIPE_PRICE_YEARLY_B`
- `STRIPE_TRIAL_DAYS=14` so checkout matches the “14 dní” copy. Unset or `0` means no trial, while the page still says 14.
- `PRICING_ADMIN_EMAIL` — your sign-in e-mail. Comma-separated if more than one. This is who may open the summary. Empty means the route answers 404.

The webhook URL does not change (`https://tokeny.martinpohl.cz/api/stripe-webhook`). Checkout writes `pricing_variant` (`control` or `b`) onto the session and the subscription. When the subscription is `trialing` or `active`, the handler records `subscribed` with that variant.

## Apply the schema

Before the new code serves traffic, apply `db/schema.sql` to the Neon `tokeny` database:

```bash
DATABASE_URL='postgresql://…' bun run db:migrate
```

That adds `profiles.pricing_variant`, `pricing_events`, `apple_sandbox_allowlist`, and replaces `public.is_pro`. It is idempotent. This change does not run that command.

## How a visitor is assigned

50/50 from the first byte of SHA-256 of the prefix `tokeny-pricing-v1`, a NUL byte, and the subject (`PRICING_HASH_PREFIX` in `server/lib/pricing.ts`). The same subject always gets the same side. 0–127 is control, 128–255 is B.

- Logged out: subject is a `tokeny_anon` cookie (UUID, HttpOnly, one year). `GET /api/pricing` sets it.
- Logged in, already stored: `profiles.pricing_variant` wins and is never overwritten.
- Logged in, not stored, and this browser already had the cookie: store the cookie’s variant, so the price they saw is the price checkout charges.
- Logged in, no cookie yet: store the hash of the user id.

`POST /api/pricing/event` with `{ "event": "view_paywall" }` records one view per person. The pricing section and the upgrade dialog send it. The client cannot record `start_checkout` or `subscribed`; checkout and the webhook do that. Repeats of the same event for the same person are ignored. A logged-out view is attached to the user when they sign in on that browser.

## Reading the result

Signed in as `PRICING_ADMIN_EMAIL`:

```http
GET /api/pricing/experiment
```

```json
{
  "experiment": true,
  "variants": {
    "control": { "view_paywall": 0, "start_checkout": 0, "subscribed": 0, "checkoutRate": null, "subscribeRate": null },
    "b": { "view_paywall": 0, "start_checkout": 0, "subscribed": 0, "checkoutRate": null, "subscribeRate": null }
  }
}
```

Counts are distinct people. `checkoutRate` is `start_checkout / view_paywall`, `subscribeRate` is `subscribed / view_paywall`. Both are null when that variant has no views. Anyone else gets 404 (or 401 if they are not signed in).

## Copy

The pricing section, the upgrade dialog, the Pro gate, Settings, and the landing FAQ show the assigned price. The yearly line stays “2 months free” at both prices. Terms (`/terms`) and the support page state the control price, 99 Kč and 990 Kč, which is the published offer. They do not mention the test. If B wins, update those pages in a later change and bump `TERMS_VERSION` in `server/lib/billing.ts`.

## iOS

One price, the control. Local StoreKit config is 99 / 990. App Store Connect prices are the nearest CZK price points to those amounts, set by the owner, not by this change. See `docs/apple-iap.md`.

Sandbox and Xcode purchases grant Pro only for ids and e-mails in `APPLE_SANDBOX_PRO_ALLOWLIST`. Leave it empty for external TestFlight.
