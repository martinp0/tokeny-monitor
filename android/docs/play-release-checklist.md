# First Play release checklist

Not a submission. No AAB from this repo has been uploaded.

Package `cz.martinpohl.tokeny`, version name `0.2.0`, version code `2`. Listing text is in `android/fastlane/metadata/android/`. Data safety draft is `android/docs/data-safety.md`. Privacy URL for this app: `https://tokeny.martinpohl.cz/android/privacy`. The website and Apple apps stay on `https://tokeny.martinpohl.cz/privacy`.

## Testing requirement

Google's help page [App testing requirements for new personal developer accounts](https://support.google.com/googleplay/android-developer/answer/14151465) says personal Play Console accounts created after 13 November 2023 must run a closed test with at least 12 testers opted in continuously for the preceding 14 days before applying for production. Production and pre-registration stay disabled until then. Internal testing is optional and does not replace the closed test. Open testing comes after production access.

The page does not say whether an organization account, or a personal account created on or before 13 November 2023, has to do the same test. This repo does not record when Martin's Play account was created or whether it is a personal or organization account, so it is unverified whether this requirement applies to him.

## Signing

Read `android/docs/signing-and-next-steps.md` before the first upload.

- The release keystore is PKCS12, alias `tokeny-release`, key password equal to the store password. It stays outside git. `bundleRelease` and `assembleRelease` sign with it only when `TOKENY_KEYSTORE_FILE`, `TOKENY_KEYSTORE_PASSWORD`, `TOKENY_KEY_ALIAS`, and `TOKENY_KEY_PASSWORD` are all set.
- Intended Play setup: enroll that key as the existing app signing key before the first open-testing or production release. [Use Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756) says a new app starts on a Google-generated key, and that an admin can change the app signing key and provide a copy of their own before a release is rolled out to open testing or production. After an open track is published, that page's release flow says the signing key is fixed.
- Upload-key option: Google recommends an upload key that is different from the app signing key. The uploaded AAB is signed with the upload key. The APKs Play installs are signed with the app signing key. The direct-download APK on the website should be signed with the app signing key whose SHA-256 is published on `/android` (`92:BD:37:70:0B:21:01:1B:39:FA:C2:7D:8F:2D:4E:F9:9B:61:0A:D0:F9:E5:FD:97:C0:D7:2F:3A:5B:11:D6:2B`), so a sideload and a Play install can update each other. This repo has not checked that fingerprint against a key.

## Before production

1. Confirm the account type and creation date against the testing article above.
2. If the 12-tester rule applies, run the closed test for 14 continuous days, then apply for production from the Play Console dashboard. The same article says the review usually takes seven days or less and can take longer.
3. Fill the store listing from the fastlane files, the Data safety form from `data-safety.md`, and the privacy policy URL above.
4. Set the content rating to match an app with no account, no ads, and no user-generated public content.
5. Do not turn on R8 for this version. Minify is off because the unit tests do not run a shrunk release build.
