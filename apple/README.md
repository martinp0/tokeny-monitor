# Tokeny for iPhone, Mac and Apple Watch

Native SwiftUI apps for [tokeny.martinpohl.cz](https://tokeny.martinpohl.cz): AI spend today and this
month in Kč and dollars, the monthly budget, and the providers and models behind it.

| Target | Platform | What it does |
| --- | --- | --- |
| `Tokeny` | iOS 26 | Dashboard, settings, App Intents, background refresh, iPhone widgets, and the embedded Watch app |
| `TokenyWidgets` | iOS 26 | Home Screen (small, medium) and Lock Screen (circular, rectangular, inline) widgets |
| `TokenyMac` | macOS 26 | Menu bar app: month figure in the menu bar, details in the panel, ⌘R / ⌘, / ⌘Q, open at login |
| `TokenyWatch` | watchOS 26 | Companion app embedded in `Tokeny`. Month, today, budget and providers sent from the iPhone. Also has its own scheme |
| `TokenyWatchWidgets` | watchOS 26 | Complications embedded in `TokenyWatch`. Bundle id `cz.martinpohl.tokeny.watchkitapp.widget` |
| `TokenyKit` (SwiftPM) | all | `TokenyCore`: models, formatting, budget rules, API client, App Group cache, StoreKit product ids. `TokenyAuth`: Neon Auth (Better Auth) client, Keychain session, Sign in with Apple |

## How it works

- **Sign-in.** E-mail and password (`/api/auth/sign-in/email`) against the same Neon Auth proxy as the
  web. The app keeps only a `neon-auth`…`session_token` cookie from that response and sends it by
  hand as `Cookie` (never through URLSession's cookie jar, and never a browser cookie jar). Password
  reset e-mails a code; the user finishes on the web (`/reset-password`). Sign in with Apple
  (`AuthenticationServices`) posts the identity token to `/api/auth/sign-in/social`. Neon Auth does not
  have the Apple provider enabled yet (`PROVIDER_NOT_SUPPORTED`), so the app then saves the Apple user
  id on the device only and shows file or sample spend. When Apple is configured with the bundle ids
  as token audiences, the same button stores a server session. The iOS and Mac targets request the
  Sign in with Apple entitlement. Without an account, the iPhone opens a usage CSV or labeled sample data
  and calculates spend and the month-end forecast on the device. That screen does not upload the file.
- **Data.** One `GET /api/usage-summary?tz=…` with the session cookie (a Neon Auth JWT as
  `Authorization: Bearer` works too). The endpoint
  returns aggregates only. `GET /api/insights?tz=…&lang=…` returns the same account's savings tips
  (model mix, cache hit rate, cheaper-model / cache / batch estimates, spikes, and key or project
  totals). Free responses use a band that contains each amount; Pro responses are exact. The signed-in
  dashboard shows them. File and sample tips stay on device (`OptimizationTips`) and do not call the
  route. Prices are copied from `shared/pricing/` by `scripts/sync-shared-pricing.sh`. Free accounts get the same limits as the web (last 30 days, no forecast, no
  previous month); `plan` in the response decides what the server sends. Pro is also an App Store
  auto-renewable subscription (monthly `cz.martinpohl.tokeny.pro.monthly`, yearly
  `cz.martinpohl.tokeny.pro.yearly`, group reference name `Tokeny Pro`). The paywall, restore, and
  StoreKit entitlement check live in the app. After a verified purchase the app posts the signed
  transaction to `POST /api/apple/transactions`, and the server grants the same Pro plan as Stripe
  (full history, forecast, and the other Pro gates). Renewals and refunds arrive at
  `POST /api/apple/notifications`. See `docs/apple-iap.md`. The apps do not link to the Stripe checkout.
- **Widgets** read the summary the app cached in the App Group (`group.cz.martinpohl.tokeny`). If it is
  older than 30 minutes and the stored session is still valid, the iPhone widget fetches once by
  itself. Widgets never write the session; only the app signs in, refreshes and signs out.
- **Apple Watch** is a companion (`WKRunsIndependentlyOfCompanionApp` = NO) embedded in the iPhone app,
  and it still has its own `TokenyWatch` scheme. It holds no credentials. The complication bundle id is
  the registered `cz.martinpohl.tokeny.watchkitapp.widget`. The iPhone sends a cached summary over
  WatchConnectivity and pushes again when the watch app is installed.
- **Budget alerts** are local notifications, once at the alert threshold and once at 100 % per month,
  evaluated whenever the app refreshes (foreground, background app refresh, Mac auto-refresh). Remote
  pushes via APNs are stubbed (`TODO(apns)` in `iOS/AppDelegate.swift` and `SharedUI/BudgetNotifier.swift`).
- **Shortcuts / Siri / Spotlight:** "Kolik jsem dnes utratil za AI?" (`SpendTodayIntent`) and
  "Je rozpočet na AI v pořádku?" (`BudgetCheckIntent`, returns a Bool for automations).

## Layout

```
apple/
├── project.yml           XcodeGen spec (the .xcodeproj is generated, not committed)
├── ci_scripts/           Xcode Cloud: generate the project, stamp the build number
├── TokenyKit/            Swift package, builds and tests on macOS and Linux
├── SharedUI/             iPhone + Mac: AppModel, sign-in, intents, notifications, String Catalogs
├── Components/           SwiftUI pieces shared by all apps and widgets
├── Widgets/              WidgetKit code for both the iPhone widgets and the Watch complications
├── Resources/            PrivacyInfo.xcprivacy
├── iOS/ macOS/ watchOS/  App entry points, platform UI, asset catalogs
└── scripts/              gen_xcstrings.py: regenerates Localizable/AppShortcuts.xcstrings (en + cs)
```

## Build locally

```sh
brew install xcodegen
cd apple
xcodegen generate
open Tokeny.xcodeproj
```

Needs Xcode 26 or newer. Pick the **Tokeny** scheme for iPhone, its widgets and the embedded Watch app
(StoreKit configuration `Config/TokenyPro.storekit` is attached to the scheme),
**TokenyWatch** to run the Watch app on its own, **TokenyMac** for the menu bar app. Unit tests (Swift Testing) run
from the iPhone or Mac scheme, or without Xcode:

```sh
cd apple/TokenyKit && swift test
```

After changing UI text, run `python3 apple/scripts/gen_xcstrings.py` (it fails if a Czech
translation is missing).

## One-time setup

1. **Apple Developer → Identifiers** (team `GR59NF57R2`): App IDs `cz.martinpohl.tokeny`,
   `cz.martinpohl.tokeny.widgets`, `cz.martinpohl.tokeny.watchkitapp`,
   `cz.martinpohl.tokeny.watchkitapp.widget`, `cz.martinpohl.tokeny.mac`. Capabilities:
   App Groups `group.cz.martinpohl.tokeny` (all but the Mac app). Enable **Sign in with Apple** on
   `cz.martinpohl.tokeny` and `cz.martinpohl.tokeny.mac` before the next signed build; the project
   requests that entitlement. Xcode's automatic signing creates the other capabilities on the first
   signed build if you let it. This repository does not sign or submit.
2. **Neon Console → project `tokeny` → Auth → OAuth providers → Apple** (not configured yet): add the
   web Services ID + key for the web button, and `cz.martinpohl.tokeny` / `cz.martinpohl.tokeny.mac`
   as allowed audiences for native ID tokens. **Unverified:** whether Neon Auth's Apple provider accepts
   native ID tokens for extra bundle IDs; until Apple is configured, hide or expect an error from the
   Apple button.
3. **Neon Auth → Trusted domains:** keep `https://tokeny.martinpohl.cz` (already set).
4. Nothing to deploy separately: `/api/usage-summary` ships with the web (Vercel).

Xcode Cloud and TestFlight: see [docs/xcode-cloud.md](../docs/xcode-cloud.md).

## App Review notes

Full notes, demo account script and privacy label answers: [docs/app-review.md](../docs/app-review.md).
Short version:
- **4.2:** fully native (no web view): widgets, complications, menu bar, App Intents.
- **5.1.1(v):** Settings → *Delete account…* (`POST /api/account/delete`, cancels Stripe too).
- **3.1.1:** Tokeny Pro is a StoreKit subscription (monthly and yearly). The paywall shows the price,
  the period, auto-renewal, and links to the privacy policy, the terms, and Apple's standard EULA.
  The account link goes to `/profile` (no Stripe checkout). Internal TestFlight only until the
  products exist in App Store Connect. Do not submit.
- **Privacy:** `PrivacyInfo.xcprivacy` = e-mail + user ID, app functionality, no tracking.
