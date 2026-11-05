# Google sign-in with our own OAuth client

Today Neon Auth uses **Neon's shared Google credentials** (`type: "shared"`), so Google's consent
screen shows Neon, not Tokeny. Neon says shared credentials are fine for development but not for
production ([Neon Docs: Set up OAuth](https://neon.com/docs/auth/guides/setup-oauth)). The Google
Cloud parts are free.

## 1. Google Cloud Console (only Martin can do this)

1. https://console.cloud.google.com/ → create or pick a project (e.g. `tokeny`).
2. **Google Auth Platform → Branding** (formerly "OAuth consent screen"):
   - App name **Tokeny**, user support email, and the logo (`public/icon-192.png` or larger).
   - App home page `https://tokeny.martinpohl.cz`, privacy policy `https://tokeny.martinpohl.cz/privacy`,
     terms `https://tokeny.martinpohl.cz/terms`.
   - **Authorized domains:** `martinpohl.cz`. Google wants the top private domain here, which covers
     `tokeny.martinpohl.cz`. Add `neon.tech` too if the console flags the redirect host (unverified;
     only do it if asked).
   - Developer contact email.
3. **Audience:** External → **Publish app** (In production). Branding is not shown while the client
   is in "Testing". Google may ask to verify the brand (logo + domain); only the basic scopes
   `openid`, `email`, `profile` are needed, so no sensitive-scope review.
4. **Clients → Create client → Web application**, name `Tokeny web`:
   - **Authorized JavaScript origins:** `https://tokeny.martinpohl.cz`
   - **Authorized redirect URIs** (exactly, no trailing slash):
     `https://ep-jolly-hill-baycw2kd.neonauth.c-8.eu-central-1.aws.neon.tech/neondb/auth/callback/google`
     This is `{NEON_AUTH_BASE_URL}/callback/google` per the Neon docs. It is *not* our
     `/auth/callback` page; that one is the `callbackURL` Neon sends users back to afterwards and it
     must stay on a trusted domain (already: `martinpohl.cz`, `pohl.uk`).
   - Every Neon branch with its own Auth URL needs its own redirect URI here.
5. Copy the **Client ID** and **Client secret**. Do not commit them or paste them in chats.

## 2. Neon Console

Project `purple-lab-69702333` → branch `br-damp-dew-bapglbzt` → **Auth → OAuth providers → Google**:
switch from shared to custom and paste the Client ID and secret. No app code change or redeploy is
needed: `authClient.signInSocial("google")` in `src/lib/auth-client.ts` already posts to Neon Auth `sign-in/social`.

## 3. Verify

- Open https://tokeny.martinpohl.cz/auth in a private window → "Pokračovat přes Google".
  The consent screen should say **Tokeny** (after branding is published/verified).
- `redirect_uri_mismatch` = the redirect URI in step 4 doesn't match the Neon Auth base URL exactly.
- Existing Google users keep working: accounts are matched by Google's user ID/e-mail, not by client.
  (Neon/Better Auth behaviour; check one existing account after switching.)

## Related open points

- Neon Auth still has `allow_localhost: true` on production; turn it off once local dev doesn't need it.
- E-mails go from Neon's shared sender `auth@mail.myneon.app`; a custom sender is separate work.
- Apple: see `docs/apple-signin.md`.
