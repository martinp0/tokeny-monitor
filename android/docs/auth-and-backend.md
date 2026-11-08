# Auth and backend verification

Checked on **8 Nov 2026** from this environment, with public read-only GETs against `https://tokeny.martinpohl.cz`. No account was created, no password was sent, no provider key was sent, and no user row was read. The Android app itself does not perform these calls: it has no `INTERNET` permission.

| Request | Result |
|---|---|
| `GET /api/health` | `200` `{"ok":true}` |
| `GET /api/exchange-rate` | `200` `{"rate":21.804,"date":"06.11.2026"}` with `Cache-Control: public, max-age=600` |
| `GET /api/usage-summary?tz=Europe/Prague` with no credential | `401` `{"error":"Unauthorized"}` |
| `GET /api/auth/get-session` with no cookie | `200` `null` |
| `GET /api/auth/token` with no session | `401` `{"message":"Unauthorized","code":"UNAUTHORIZED"}` |

The date on the public exchange rate is the Czech `D.M.YYYY` string the server stores, not an ISO day. The sample inside the app uses its own rate (`23.4`, dated `2026-10-29`) and says so. It is not presented as that live ČNB figure.

`main` at the time of the branch is `5c775f6b1171246c65d827860cc643f932d0b015`, the merge of PR **#41** (“První návštěva: označená ukázka, import CSV a co z dat umí Pro”). The local snapshot before `git fetch` was one commit behind, at #40.

## What the server actually accepts

`server/auth.ts` and `GET /api/usage-summary` in `server/app.ts` authenticate a caller in three ways:

1. A first-party Neon Auth session cookie (`neon-auth` / `__Secure-neon-auth.session_token`), set by the same-origin proxy `POST /api/auth/*`. The web client never reads the cookie (`src/lib/auth-client.ts`). `get-session` without it is `null`.
2. `Authorization: Bearer <Neon Auth JWT>`. The JWT is EdDSA, checked against `${NEON_AUTH_BASE_URL}/.well-known/jwks.json`, and `sub` must be a UUID. Neon Auth’s managed JWT is documented as about 15 minutes, with no custom claims. Minting it is `GET /api/auth/token`, which this check saw return 401 unless a session already exists.
3. A personal `orm_` + 64 hex token. It is stored only as a SHA-256 hash, it is Pro-only, and it also authorizes the MCP server. It is created from an already signed-in web session (`POST /api/mcp-tokens`).

Provider keys (Anthropic, OpenAI, OpenRouter) are encrypted on the server and are never returned. This app does not ask for them and does not have a place to store them.

## What this app does with that

Nothing over the network. `CredentialPolicy` (`rejectCredential` in `android/core`) rejects every shape: blank, cookie-shaped (`=` / `session_token`), provider-key prefixes (`sk-`, `sk_`, `or-`, `anthropic`), `orm_` tokens, and JWT-shaped strings. There is no screen that asks for any of them, no `Authorization` header is built, and the UI sources are tested to keep it that way.

The sample JSON is parsed with the same parser as a version-1 `usage-summary` body, then shown only while the phase is a demo. A missing `plan` is treated as Pro, matching the legacy personal-token payload the Apple client already documents. Version 2 is rejected rather than guessed.

A second pass the same day also recorded 401 `{"error":"Unauthorized"}` for `GET /api/me`, `/api/activity`, `/api/budget`, `/api/subscription`, `/api/alerts`, and `/api/credentials`. The full table and the JWT check as the code implements it are in [api-coordination.md](api-coordination.md). No redirect or PKCE flow was tested, and none is claimed to work.

Local CSV import does not call these routes. See [local-csv.md](local-csv.md).

## Live, sample, import, and missing

| Surface | Status |
|---|---|
| `GET /api/health`, `GET /api/exchange-rate` | Live and public. Verified above. Not called by the app. |
| `GET /api/usage-summary` | Live, but private. Anonymous call is 401. Not called by the app. |
| Spend from a CSV the user confirms | **On this phone only.** Private `local-ledger.json`. USD. Prague days. Not a sample and not an account. |
| Sample overview | **Sample only.** October 2026 fixture. The banner says so. It is not combined with the ledger. |
| Free sample | Matches the server: no previous month, no forecast, no budget. Copy states that Pro on the web includes those and that this app does not sell Pro. |
| Sign-in, session refresh, notifications, exports, shares, CSV import, chat | **Missing.** Not faked. |
| Play Billing, Stripe, external checkout | **Not implemented.** |

A labeled sample is the only spend the phone can show. Closing it returns to the signed-out screen.
