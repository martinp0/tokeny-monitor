# Sign in with Apple (Neon Auth): what Martin has to do

**Status 2026-11-05:** off. Neon Auth (project `purple-lab-69702333`, branch `main` / `br-damp-dew-bapglbzt`)
has only `google` with **shared** dev credentials (`type: shared`). Apple has no shared app in Neon
Auth, so it needs your own credentials. The web button already exists (`src/pages/Auth.tsx`) and
stays hidden until the build has `VITE_AUTH_APPLE_ENABLED=true`. No code change is needed.

**Cost:** Sign in with Apple needs a paid Apple Developer Program membership (99 USD/yr). If you
already have it for the iOS/Mac apps (`docs/xcode-cloud.md`), it costs nothing extra.

## 1. Apple Developer (developer.apple.com → Certificates, Identifiers & Profiles)

1. **Team ID:** top right of the account page (10 characters). → `apple_team_id`
2. **App ID** (Identifiers → App IDs): use the existing `cz.martinpohl.tokeny` (iOS) and
   `cz.martinpohl.tokeny.mac` (macOS). Tick the **Sign in with Apple** capability on the primary one.
3. **Services ID** (Identifiers → Services IDs → +): e.g. `cz.martinpohl.tokeny.web`, description
   "Tokeny web". Enable **Sign in with Apple** → Configure:
   - Primary App ID: `cz.martinpohl.tokeny`
   - **Domains:** `ep-jolly-hill-baycw2kd.neonauth.c-8.eu-central-1.aws.neon.tech` and `tokeny.martinpohl.cz`
   - **Return URL:** `https://ep-jolly-hill-baycw2kd.neonauth.c-8.eu-central-1.aws.neon.tech/neondb/auth/callback/apple`
     (the OAuth flow is completed by Neon Auth, not by our domain; same as Google. This path follows
     Better Auth's `/callback/<provider>` convention. **Confirm it in Neon Console → Auth → Apple**
     before saving; if the console shows a different URL, use that one.)
   → the Services ID is `client_id`.
4. **Key** (Keys → +): name "Tokeny Sign in with Apple", tick **Sign in with Apple**, configure with
   primary App ID `cz.martinpohl.tokeny`. Download the `.p8` (only once!). Note the **Key ID**.
   → `.p8` content = `client_secret`, Key ID = `apple_key_id`. Store the `.p8` in your password
   manager; never commit it or paste it in chat.

## 2. Neon Auth

Neon Console → project Tokeny → Auth → OAuth providers → **Apple** → fill Services ID, Team ID,
Key ID and the `.p8` content. (Same as the Neon MCP call `add_auth_oauth_provider` with
`id: "apple"`, `client_id`, `client_secret`, `apple_team_id`, `apple_key_id` on branch
`br-damp-dew-bapglbzt`. An agent can do it only once you put the values into the vault, not in chat.)

Trusted domains already contain `https://tokeny.martinpohl.cz`. Apple returns with a `form_post`
from `https://appleid.apple.com`; Better Auth's docs list that origin as trusted for Apple. If the
first login fails with an origin error, add `https://appleid.apple.com` to trusted domains
(unverified whether Neon Auth needs it).

## 3. Turn on the button

Vercel → project `martinp0-tokeny-monitor` → Environment Variables → `VITE_AUTH_APPLE_ENABLED=true`
(Production), then redeploy (it's a build-time variable).

## 4. Check

1. https://tokeny.martinpohl.cz/auth → "Pokračovat přes Apple" → Apple login → back on `/dashboard`.
2. Try "Hide my email": the account gets a `@privaterelay.appleid.com` address. Emails from
   Neon Auth to it only arrive if the sender domain is registered in Apple → Services → Sign in with
   Apple for Email Communication (Neon's shared sender `auth@mail.myneon.app` is not yours; open point).
3. Apple requires that users can delete the account: already in Profile → Smazat účet.

## Native apps (iOS/macOS)

The iPhone and Mac apps show Sign in with Apple (`AuthenticationServices`) and request the
entitlement on `cz.martinpohl.tokeny` and `cz.martinpohl.tokeny.mac`. The button posts the identity
token to `POST /api/auth/sign-in/social` with `provider: apple`, `disableRedirect: true`, and
`idToken.token` / `idToken.nonce` (the raw nonce; Apple receives only its SHA-256).

Until the Apple provider is enabled, that call returns `400` `PROVIDER_NOT_SUPPORTED` and the app
saves the Apple user id on the device only (no server session, spend from a file or sample data).
That device-only identity cannot start an App Store purchase: StoreKit needs an `appAccountToken`
derived from the Neon Auth user id. The Pro sheet and Settings ask for the email and password of a
Tokeny account instead, and keep Sign in with Apple on the sign-in screen. When this provider
accepts the identity token, `AuthService.signInWithApple` returns a server session and that same
sheet can buy Pro without another code change.
The same fallback is used when Better Auth rejects the token audience: a native token's `aud` is the
bundle id, not the Services ID. Add `cz.martinpohl.tokeny` and `cz.martinpohl.tokeny.mac` as audiences
(`appBundleIdentifier`, or `clientId` / `audience` as a list next to the Services ID) or the button
keeps the local identity. Enable Sign in with Apple on those App IDs before the next signed build.

## Related open points (seen while checking, not changed)

- Google uses Neon's **shared** dev credentials (consent screen shows Neon, not Tokeny). For
  production, create your own Google OAuth client (free); its redirect URI is
  `https://ep-jolly-hill-baycw2kd.neonauth.c-8.eu-central-1.aws.neon.tech/neondb/auth/callback/google`
  (same caveat: confirm in the Neon Console).
- `allow_localhost: true` on the prod branch; turn it off when nobody develops against prod.
- Auth emails go out through Neon's shared sender (`auth@mail.myneon.app`, "Neon Auth").
