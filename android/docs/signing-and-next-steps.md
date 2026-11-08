# Signing, store, and monetization

Nothing in this change creates a Play Console listing, an upload key, a subscription, or a Stripe session. No account was edited.

## Signing

- `./gradlew :app:assembleDebug` produces `android/app/build/outputs/apk/debug/app-debug.apk`.
- The debug keystore is the one the Android SDK creates on the machine that builds. It is not in git. `android/.gitignore` ignores `*.keystore`, `*.jks`, and `*.apk`.
- A release build is not configured and minify is off. Do not commit a release keystore or a password. When a release exists, use Play App Signing, keep the upload key outside the repo, and record its SHA-256 separately.
- `compileSdk` and `targetSdk` are 37. `minSdk` is 26. `applicationId` and namespace are `cz.martinpohl.tokeny`. `versionName` is `0.2.0`, `versionCode` is 2. Edge-to-edge insets are applied explicitly. The debug APK is signed with the machine debug keystore, which is not committed.
- Backup and device transfer are off (`allowBackup=false` plus empty backup rules). There is no account data to restore. Cleartext HTTP is off. There is no `INTERNET` permission until a real session exists.

## Store

Do not submit this build. It is a signed-out sample, it has no privacy-policy URL of its own (the web has `/privacy`), and it has no content rating. Before a listing:

- Confirm the mobile auth contract in `api-coordination.md` and test it with a real session that the owner authorizes.
- Data safety: this build collects nothing and contacts no server. A later signed-in build would send the Bearer token only to `tokeny.martinpohl.cz` and would show server aggregates, not raw provider keys.
- Declare that there is no advertising SDK and no analytics SDK in this module. Do not add either as part of the first store build without a separate decision.

## Monetization

The web already distinguishes Free and Pro. Pro on the server is a Stripe subscription (99 Kč / month, 990 Kč / year in the web copy). The summary’s `plan` field is the entitlement. This app:

- Shows a Free sample without budget or forecast, and says those are part of Pro on the web.
- Says in that same sentence that the app does not sell Pro and does not open a payment.
- Has no Play Billing client, no Stripe link, no Buy Me a Coffee link, and no price button.

A later Pro purchase on Android has to be a real billing integration, or it stays on the web. An external checkout link from the app is not a substitute and is not included here. Notifications for the 50/80/100 percent budget alerts are also not registered; the sample text says the web checks those once a day.
