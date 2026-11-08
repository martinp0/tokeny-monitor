# Mobile session: what was checked, and what is not proposed as working

Checked with unauthenticated GETs on **8 Nov 2026** against `https://tokeny.martinpohl.cz`. No body carried a cookie, a bearer token, or a password. No account was created. `POST /api/activity/import` was not called. The Android app still has no `INTERNET` permission; these calls were from the build environment.

This is not a claim that an arbitrary JWT, a custom redirect, or PKCE already works. None of those were exercised, and this repository does not register a native redirect.

## Endpoints

| Request | Observed status | What the server code actually does |
|---|---|---|
| `GET /api/health` | 200 `{"ok":true}` | Public. `server/app.ts`. |
| `GET /api/exchange-rate` | 200 `{"rate":21.804,"date":"06.11.2026"}`, `Cache-Control: public, max-age=600` | Public ČNB figure. The date string is `D.M.YYYY` as stored, not an ISO day. The import screen does not use it. |
| `GET /api/auth/get-session` | 200 `null` | Same-origin proxy to Neon Auth (`handleAuthProxyRequest` in `server/auth.ts`). No `neon-auth` cookie means a JSON `null`, not a user. |
| `GET /api/auth/token` | 401 `{"message":"Unauthorized","code":"UNAUTHORIZED"}` plus `x-neon-ret-request-id` | The proxy is mounted (`app.all("/auth/*")`). Without a session the token route refuses. A JWT was not issued in this check. |
| `GET /api/usage-summary?tz=Europe/Prague` | 401 `{"error":"Unauthorized"}` | `server/app.ts`: an `orm_` bearer is a Pro personal token (sha256 in `mcp_tokens`). Any other bearer is `sessionUser`. Otherwise the cookie session. |
| `GET /api/me` | 401 `{"error":"Unauthorized"}` | Behind `sessionUser` only. An `orm_` token is not a session (`sessionUser` returns the cookie user when the bearer starts with `orm_`, and there is no cookie). |
| `GET /api/activity` | 401 `{"error":"Unauthorized"}` | Same session gate. |
| `GET /api/budget` | 401 `{"error":"Unauthorized"}` | Same session gate, then a Pro check in the handler. Not reached anonymously. |
| `GET /api/subscription` | 401 `{"error":"Unauthorized"}` | Same session gate. |
| `GET /api/alerts` | 401 `{"error":"Unauthorized"}` | Same session gate. |
| `GET /api/credentials` | 401 `{"error":"Unauthorized"}` | Same session gate. Returns only a masked preview of provider keys when a session exists. |

`POST /api/activity/import` is the web CSV write. The handler requires `sessionUser`, a JSON `{ rows }` array, and at most 2000 rows. `ignoreDuplicates: true` keeps existing `generation_id`s; the default upsert overwrites them. It was not called.

## How a bearer is verified today

`userFromJwt` in `server/auth.ts`:

1. Take `Authorization: Bearer <token>` when the token does not start with `orm_`.
2. Verify the signature with `jose.jwtVerify` against the JWKS at `${NEON_AUTH_BASE_URL}/.well-known/jwks.json`.
3. Require `sub` to be a UUID. Email, name, and image are copied only when those claims are strings.

`NEON_AUTH_BASE_URL` and `NEON_AUTH_COOKIE_SECRET` stay on the server. The cookie secret is what lets the proxy read the HttpOnly `neon-auth` session cookie (`SameSite=Lax`). A native client that copied that cookie would be doing what the Apple client does. This Android app does not.

The comment in `server/auth.ts` calls the bearer path “native apps”. The only minting route this repo proxies, `GET /api/auth/token`, returned 401 with no session. There is no refresh grant, public client id, or Android redirect in this repository. Trusted web origins are documented as `https://tokeny.martinpohl.cz` and `https://tokeny.pohl.uk` (`CLAUDE.md`). A redirect such as `cz.martinpohl.tokeny://auth/callback` is **not** registered here, and this check did not prove Neon Auth would accept it.

## What is missing before a phone can read an account

A future change, not made in this pull request, has to be specified and then tested with a real session the owner authorizes. Until that test exists, the app must not offer a sign-in form. The minimum that would have to be shown to work:

1. A documented way for a public native client, with no client secret in the APK, to obtain a JWT that `userFromJwt` already accepts (EdDSA, JWKS, UUID `sub`).
2. A way to replace that JWT when it expires. The token route observed here does not do that without an existing session cookie.
3. An allow-list entry for whatever redirect or device flow is chosen. Adding the entry is a Neon Auth setting, not an Android change.
4. A decision that the phone calls `GET /api/usage-summary` with that bearer, and does not receive provider keys or `orm_` MCP tokens.

`orm_` remains a Pro MCP credential created from a web session. It is the wrong credential to paste into a phone.

Local CSV import does not need any of those routes. It is not an account, it has no plan, and it does not write `activity_rows`.
