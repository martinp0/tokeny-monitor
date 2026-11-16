# App Store Pro → server Pro

An App Store subscription grants the same Tokeny Pro as Stripe: full history, the month-end forecast, budget alerts, more than one provider, exports, sharing, MCP. The server decides. The app's plan label follows `plan` on `GET /api/usage-summary`.

StoreKit 2 transactions and App Store Server Notifications V2 are verified **on the server**, locally, against Apple Root CA - G3 (`server/lib/apple-root-ca-g3.ts`). No App Store Server API call, no App Store Connect API key, and no new paid service. The optional key below is unused.

## What you set in App Store Connect

Bundle id of the iPhone app: `cz.martinpohl.tokeny`. The Mac app is `cz.martinpohl.tokeny.mac`. Both are accepted. Product ids (subscription group reference name **Tokeny Pro**):

- `cz.martinpohl.tokeny.pro.monthly`
- `cz.martinpohl.tokeny.pro.yearly`

Server Notifications, version **V2**, for both environments, same URL:

- Production: `https://tokeny.martinpohl.cz/api/apple/notifications`
- Sandbox: `https://tokeny.martinpohl.cz/api/apple/notifications`

App Store Connect → your app → App Information → App Store Server Notifications. Choose **Version 2**. Paste that URL into Production and into Sandbox. Save.

`/api/*` on `tokeny.pohl.uk` is not redirected (a 301 would turn the POST into a GET). Point the notification URL at `tokeny.martinpohl.cz` anyway.

Then send a test notification from App Store Connect. The server answers `200` with `{ "ok": true, "applied": false }` when the signed payload verifies and there is no transaction to apply. A `400` means the signature did not verify.

No other secret is required for this to work. Do not add an in-app purchase key to the repo.

## Account token

Every purchase is made with StoreKit's `appAccountToken`:

```
appAccountToken = UUIDv5(namespace, lowercase Tokeny user id)
namespace       = b7e1c4a2-5d38-4f0e-9c61-2a8e6f0d4b93
```

UUID version 5, RFC 4122. The name is the Neon Auth user id, trimmed, lowercased, and it must already be a UUID. The same account always gets the same token. The Swift function is `AppAccountToken.string(forUserId:)` and the server function is `appAccountTokenForUser`. Do not change the namespace: transactions already in the App Store are bound to it.

The app refuses to start a purchase until there is a server session. The on-device Apple identity (the fallback when Neon Auth has no Apple provider) is not a Tokeny user id, so it cannot buy.

`POST /api/apple/transactions` (session cookie or Neon Auth JWT) accepts the JWS only when the token matches the caller. One Apple `originalTransactionId` belongs to one Tokeny user. A second account gets `409 apple_transaction_in_use`.

## What the server checks

On each JWS (`x5c`, ES256):

1. The certificate chain ends at the pinned Apple Root CA - G3 (or is signed by it). Tests inject a different root in code. Nothing in the environment can swap the production root.
2. The leaf carries Apple's App Store OID `1.2.840.113635.100.6.11.1` and is not a CA.
3. `bundleId` is `cz.martinpohl.tokeny` or `cz.martinpohl.tokeny.mac`.
4. `productId` is one of the two ids above.
5. `environment` is `Production`, `Sandbox`, or `Xcode`.
6. `type` is `Auto-Renewable Subscription`, and `expiresDate`, `revocationDate` and `signedDate` are read off the payload. An older `signedDate` than the one already stored does not overwrite it.

`public.is_pro(uuid)` is true when the Stripe row would grant Pro **or** an App Store row is `active` until `expires_at`, or `grace` until `grace_expires_at`, and has not been revoked. Billing retry, expiry, refund and revocation do not grant Pro. That is the same rule as `isProAccount` in `server/lib/plan.ts`.

Notifications handled: `DID_RENEW`, `EXPIRED`, `DID_FAIL_TO_RENEW` (subtype `GRACE_PERIOD` keeps Pro until the grace date; otherwise it does not), `GRACE_PERIOD_EXPIRED`, `REFUND`, `REVOKE`, `DID_CHANGE_RENEWAL_STATUS` (turning auto-renew off does not end Pro early). `SUBSCRIBED` is applied the same way, so a notification can grant Pro even if the app did not finish its POST. `TEST` is acknowledged and changes nothing.

Sandbox notifications and sandbox purchases grant Pro on this server. That is how you verify it. The environment is stored on the row.

## How to verify in sandbox

The local StoreKit file (`apple/Config/TokenyPro.storekit`) is for the paywall UI only. Those transactions are signed by Xcode, not by Apple, so the server rejects them. Use a Sandbox Apple ID on a device or TestFlight build that talks to `https://tokeny.martinpohl.cz`.

1. Deploy this server (so `/api/apple/transactions` and `/api/apple/notifications` exist) and apply `db/schema.sql` (`bun run db:migrate` against the Neon `tokeny` database).
2. Set the notification URLs above.
3. On the device, sign in to a Tokeny account (e-mail or Sign in with Apple that reaches the server, not the on-device fallback).
4. Buy the monthly or yearly subscription with the Sandbox Apple ID.
5. Pull to refresh. Settings → Plan should say **Pro**, and the usage summary should include history older than 30 days and a forecast. The website, signed in as the same account, should show Pro as well. An App Store subscription is managed under Settings → Apple ID → Subscriptions, not in the Stripe portal.
6. In App Store Connect, send a Sandbox test notification and confirm the request log shows `200`.
7. Let a sandbox renewal happen (sandbox renews much faster than production), or refund the transaction from the sandbox account settings. The plan should follow: renewal keeps Pro, refund or expiry drops it back to Free without opening the app, as long as Apple can reach the notification URL.

## Optional App Store Server API key

Not required. Local verification does not call Apple.

If you later want Get Transaction Info or Get Notification History, create an App Store Connect API key (Users and Access → Integrations → In-App Purchase) and set these on Vercel, production only, never in git:

- `APPLE_ISSUER_ID`
- `APPLE_KEY_ID`
- `APPLE_PRIVATE_KEY` — the `.p8` PEM, including the BEGIN/END lines

`appleServerApiConfigFrom` in `server/lib/apple-server-api.ts` returns null unless all three are set. The request path does not read them today.
