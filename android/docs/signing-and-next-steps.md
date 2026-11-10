# Signing, store, and monetization

Nothing in this change creates a Play Console listing, an upload key, a subscription, or a Stripe session. No account was edited.

## Signing

- `./gradlew :app:assembleDebug` produces `android/app/build/outputs/apk/debug/app-debug.apk`, signed with the SDK debug keystore. That keystore is not in git.
- `./gradlew :app:assembleRelease` and `./gradlew :app:bundleRelease` sign the release only when all four values are set: `TOKENY_KEYSTORE_FILE`, `TOKENY_KEYSTORE_PASSWORD`, `TOKENY_KEY_ALIAS`, `TOKENY_KEY_PASSWORD`. Each one may come from the environment, a Gradle property, or an untracked `android/keystore.properties`. If none are set, the release APK and the AAB stay unsigned. If some are set and some are not, configuration fails and names the missing variables. It does not print the values.
- The prepared keystore is PKCS12. The alias is `tokeny-release`. The key password is the same as the store password. `storeType` is `pkcs12`. `android/.gitignore` ignores `*.keystore`, `*.jks`, `*.p12`, `keystore.properties`, and `*.apk`.
- That key is the intended app signing key. In Play Console, a new app starts on a Google-generated key. Before the first open-testing or production release, change the app signing key and provide a copy of this key ([Use Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)). Google recommends a different upload key for the AAB. If you use one, sign the Play upload with the upload key and keep this key for the website APK, so the installed certificate matches the fingerprint on `/android`.
- The website fingerprint `92:BD:37:70:0B:21:01:1B:39:FA:C2:7D:8F:2D:4E:F9:9B:61:0A:D0:F9:E5:FD:97:C0:D7:2F:3A:5B:11:D6:2B` is the value to publish. This repo does not contain the key, so it has not checked the fingerprint.
- Minify stays off. See `app/build.gradle.kts`.
- `compileSdk` and `targetSdk` are 37. `minSdk` is 26. `applicationId` and namespace are `cz.martinpohl.tokeny`. `versionName` is `0.2.0`, `versionCode` is 2. Nothing has been published, so the version was not bumped. Edge-to-edge insets are applied explicitly. The debug APK is signed with the machine debug keystore, which is not committed.
- Backup and device transfer are off (`allowBackup=false` plus empty backup rules). There is no account data to restore. Cleartext HTTP is off. There is no `INTERNET` permission until a real session exists.

## Store

Do not submit this build from CI. The direct-download page is `/android`. The app privacy policy is `/android/privacy`. Play listing text is in `android/fastlane/metadata/android/`. The first Play release still needs the checklist in `play-release-checklist.md`. Before a listing:

- Confirm the mobile auth contract in `api-coordination.md` and test it with a real session that the owner authorizes.
- Data safety: this build collects nothing and contacts no server. A later signed-in build would send the Bearer token only to `tokeny.martinpohl.cz` and would show server aggregates, not raw provider keys.
- Declare that there is no advertising SDK and no analytics SDK in this module. Do not add either as part of the first store build without a separate decision.

## Monetization

The web already distinguishes Free and Pro. Pro on the server is a Stripe subscription (99 Kč / month, 990 Kč / year in the web copy). The summary’s `plan` field is the entitlement. This app:

- Shows a Free sample without budget or forecast, and says those are part of Pro on the web.
- Says in that same sentence that the app does not sell Pro and does not open a payment.
- Has no Play Billing client, no Stripe link, no Buy Me a Coffee link, and no price button.

A later Pro purchase on Android has to be a real billing integration, or it stays on the web. An external checkout link from the app is not a substitute and is not included here. Notifications for the 50/80/100 percent budget alerts are also not registered; the sample text says the web checks those once a day.
