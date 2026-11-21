# Spend insights

`GET /api/insights` is the shared savings analysis for the web dashboard, the signed-in iOS app, and a later Android client. It uses the same session cookie, Neon Auth JWT, or Pro `orm_` token as `GET /api/usage-summary`.

The rules live in `server/lib/insights.ts`. They follow `apple/TokenyKit/Sources/TokenyCore/OptimizationTips.swift`: a cheaper model for repetitive work, prompt-cache savings, a batch-tier estimate, a spend spike, and a missing monthly budget. The response also includes a model-mix breakdown, the cache hit rate, and per-API-key and per-project totals when a row has a key name or a project id.

Every dollar figure is recorded spend, or tokens from those rows multiplied by `shared/pricing/model-prices.json`. A model with no row gets no price. The cache tip's 50% share is returned as `assumed_share`; it is the rule, not a measurement of repeated prompts. Each priced tip includes `explanation`, `price_source` and `price_checked`.

The catalog is the list in `shared/pricing/model-prices.sources.md` (official Anthropic, OpenAI, Gemini and xAI pages, checked 2026-11-17). Edit that JSON, then run `scripts/sync-shared-pricing.sh` so the Swift package resource matches. Xcode Cloud runs the script from `apple/ci_scripts/ci_post_clone.sh`. The iOS and Mac schemes run it as a pre-action. The copy is a real file, not a symlink.

## Plan

`insightAmounts` in `server/lib/plan.ts`:

- **Pro** (`amounts: "exact"`): `saving.usd` and `saving.czk` at the stored ČNB rate. CZK is omitted when that rate is missing.
- **Free** (`amounts: "range"`): the same computed USD amount is replaced by the smallest band that contains it. The edges are 0, 1, 5, 20, 100, 500, 2,000 and 10,000 USD, and the last band is open. The band is not a second estimate. The route does not return 403.

The window is the current month in the caller's time zone (`tz`, default Europe/Prague), and never earlier than the free history floor. Local on-device tips (`OptimizationTips`) stay on the device and do not call this route.
