# Play Data safety draft (Android app only)

Draft answers for the Play Console Data safety form. They describe `cz.martinpohl.tokeny` version 0.2.0 (version code 2) as built in this repo. They are not a completed Console submission.

## What the manifest allows

`android/app/src/main/AndroidManifest.xml` requests one permission: `android.permission.ACCESS_NETWORK_STATE`.

It does not request `INTERNET`. `android:usesCleartextTraffic` is `false`. `network_security_config.xml` sets `cleartextTrafficPermitted` to `false`. There is no analytics SDK, advertising SDK, or HTTP client in `android/app/build.gradle.kts`.

`ACCESS_NETWORK_STATE` is read on the device to label the bundled sample as offline. That check is not sent anywhere.

`android:allowBackup` is `false`. Backup and device-transfer rules are empty.

## Data stored on the device

When the user picks a CSV and confirms the preview, the app writes `files/local-ledger.json` under the app's private `filesDir` (`SpendViewModel`). The file holds parsed rows: generation id, timestamps, Prague calendar day, USD cost, token counts, model, provider, source label, request count, and an optional billing label. It does not store a name, an email, a password, a card number, or the user's location. Prague is the time zone used to group days, not a location permission.

The original CSV is read through the system document picker. The app does not keep a second copy of the file outside the parsed ledger.

Bundled sample summaries ship inside the app. They are not the user's data.

## Suggested form answers

| Question | Answer |
| --- | --- |
| Does the app collect or share any of the required user data types? | No data is shared. Data the user imports is stored only on the device. |
| Data shared | None. |
| Data collected (transmitted off the device) | None. |
| Financial info, location, personal info, messages, photos, audio, files and docs, calendar, contacts, app activity, web browsing, device or other IDs | Not collected and not shared. The imported cost figures stay in private storage. Do not mark them as collected if Play's definition requires transmission off the device. |
| Is data encrypted in transit? | Not applicable. The app has no network calls, so there is no transit. Do not answer yes. |
| Can users request deletion? | Yes, in the app: **Smazat import z telefonu** / **Delete the import from this phone**, then confirm. That deletes `local-ledger.json`. Uninstalling the app deletes its private storage. There is no account to delete on a server. |
| Committed to Play Families / ads | No ads. No ad SDK. |

If Play's form uses "collected" for data that never leaves the device, the matching statement is still: the only user-provided records are the CSV rows the user chooses to save, they stay in app-private storage, and the user can delete them.
