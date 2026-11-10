# Android developer verification (sideload)

Checked against Google's pages on 10 November 2026. This is not legal advice, and it does not register the app.

## What is in force, and where

[Android developer verification](https://developer.android.com/developer-verification) says protections begin on 30 September 2026 for users installing apps from participating stores in select regions on certified Android devices, and that verification expands globally in 2027.

The [overview guide](https://developer.android.com/developer-verification/guides) names the first regions as Brazil, Indonesia, Singapore, and Thailand, on certified devices. The participating stores it lists are Google Play, Honor, OPPO, Samsung Galaxy Store, Transsion, vivo, and Xiaomi. The Czech Republic is not in that list. The European Union is not named as a first-wave region.

The [FAQ](https://developer.android.com/developer-verification/guides/faq), updated 15 July 2026, says the 30 September 2026 deadline applies only to those participating stores. Direct sideloading, and stores that are not on the list, are not covered yet. It still says to finish verification before the 2027 global rollout. The same FAQ says ADB installs do not require registration.

So a direct APK from `tokeny.martinpohl.cz` is not in the September 2026 enforcement, and a user in the Czech Republic is not in the first four countries.

## What a developer does

The [overview guide](https://developer.android.com/developer-verification/guides) describes three paths:

- Full distribution: identity verification, then register the package by proving the signing key. Distribute from a site or a store.
- Limited distribution: no government ID. [The limited-distribution guide](https://developer.android.com/developer-verification/guides/limited-distribution) says this account is free and can share with up to 50 devices that the user authorizes. The FAQ, updated 18 June 2026, still says up to 20 devices. Those two official pages disagree, so the cap is uncertain.
- Unregistered sideload: the user completes an advanced flow. The [Android Developers blog post](https://developer.android.com/blog/posts/android-developer-verification-building-a-safer-ecosystem-together) describes that flow, including a one-day wait.

The FAQ, last updated 25 March 2026, says the full Android Developer Console account has a 25 USD fee, similar to Play's registration fee, and that the fee is waived for a limited-distribution account. It also says payment details would come when the console launches. That sentence may be stale: the timeline above puts the console launch in August 2026, and this check did not find a newer official fee.

An existing Play Console account can be the place to register apps that are also distributed outside Play, according to the FAQ. Whether that path charges the 25 USD again is not stated.

An organization account needs a D-U-N-S number. Whether Google treats a Czech OSVČ with an IČO as an organization is not stated.

## Still uncertain

- The calendar date in 2027 when the Czech Republic or the rest of the EU is included, and whether a website APK is blocked then or only sent through the advanced flow.
- Whether the limited-distribution cap is 20 or 50 devices.
- Whether Martin's existing Play account already covers outside-Play registration without another fee.
- Whether an OSVČ registers as an individual or an organization.
