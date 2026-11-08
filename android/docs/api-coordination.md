# Proposal: mobile session for Tokeny Android

This is a proposal for the Tokeny backend (the app at `tokeny.martinpohl.cz` / `tokeny.pohl.uk`). **It is not implemented in this pull request.** No route, schema, Neon Auth setting, or environment variable was changed.

## What Android can already consume

`GET /api/usage-summary?tz=Europe/Prague` is the right read model. Version 1 already returns `plan`, today, month, `previous_month`, `forecast_month_usd`, `forecast` (`low_usd`, `high_usd`, `confidence`, `days_observed`, `method`), `budget`, `usd_czk`, `daily`, `top_models`, `providers`, and `last_activity_at`. Costs stay in USD. The Prague forecast is the same one the web uses. No new spend endpoint is required for this MVP.

The gap is how a phone proves who is calling.

## Why the current three credentials are not a mobile session

- The browser session is an HttpOnly cookie on the site origin. Copying it into the app is what the Apple client does. This Android app will not do that: a cookie jar is not a public client, and the task for this MVP forbids copied browser cookies.
- `GET /api/auth/token` mints a Neon Auth JWT only when that cookie session already exists (verified 401 without it, 8 Nov 2026). The JWT is short (about 15 minutes) and there is no refresh grant a native client can call without the cookie.
- An `orm_` token is a Pro MCP credential. Putting it on a phone would grant more than a read-only summary, and creating it still requires the web session. The app rejects that shape on purpose.
- Trusted auth domains today are web origins. There is no registered redirect for an Android app link, and no public OAuth client id that would let the app run Authorization Code + PKCE without a client secret.

## What to add

A public native client, no client secret embedded in the APK:

1. Authorization Code with PKCE (or a device-code flow) for redirect `cz.martinpohl.tokeny://auth/callback`.
2. Allow that redirect on the Neon Auth trusted list. Do not put `NEON_AUTH_COOKIE_SECRET`, `DATABASE_URL`, or `CREDENTIALS_ENCRYPTION_KEY` in the app.
3. Token response: the same EdDSA JWT `server/auth.ts` already verifies (`sub` = user UUID, `email` optional), plus a refresh token bound to this client so the phone is not stuck re-prompting every 15 minutes.
4. Keep `GET /api/usage-summary` as the only spend call, with `Authorization: Bearer <jwt>`. Cookie authentication can stay for the web.
5. Prefer a read-only mobile credential over reusing `orm_` tokens, so a phone login cannot call MCP tools.
6. Leave entitlements on the server. `plan` is already on the summary. Free omits forecast and previous month; Pro includes them. The app should keep treating a 403 `{ "error": "pro_required" }` as “not in this plan”, not as a checkout.

## What not to add for this client

- Do not ask the phone for Anthropic, OpenAI, or OpenRouter keys. BYOK stays in the encrypted `ai_keys` / `provider_credentials` rows on the server.
- Do not add a Play Billing or Stripe link in the app as a substitute for that session. External purchase links are a Play policy problem, and this MVP does not sell Pro.
- Do not weaken `usage-summary` to return rows without a verified user.

Until that contract exists and has been tried with a real session, the Android app stays on the labeled sample.
