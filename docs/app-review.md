# App Review: Tokeny for iPhone, Mac and Apple Watch

Status: **internal TestFlight only. Do not archive or submit.** Rules quoted from the
[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), which were
last updated on Oct 16, 2026 (read on Oct 30, 2026). Anything marked *(unverified)* still needs
checking against App Store Connect.

## 1. Payments: how we comply

**Approach: Tokeny Pro is a StoreKit 2 auto-renewable subscription (monthly and yearly). The apps
do not link to the Stripe checkout.** Create the products in App Store Connect before a signed
TestFlight build can load them outside the local StoreKit file. Do not submit.

| What the user has | What the app shows |
|---|---|
| Neither web Pro nor an App Store subscription | Paywall: price and period from StoreKit, auto-renew disclosure (including the Czech 14-day withdrawal note), links to privacy, terms, and Apple's standard EULA, subscribe and restore. |
| App Store subscription, web plan still Free | "Pro" from the entitlement. History and the server forecast still follow the web plan until a receipt is linked on the server. |
| Web Pro | Server `plan: pro`. No paywall. |

Code:
- Product ids and the legal text: `apple/TokenyKit/Sources/TokenyCore/ProSubscription.swift`.
- StoreKit 2: `apple/SharedUI/ProStore.swift`, paywall `apple/SharedUI/ProPaywallView.swift`.
- Local testing: `apple/Config/TokenyPro.storekit` (Czech storefront, 49 Kč / 399 Kč), attached to the Tokeny and TokenyMac schemes.
- `PurchaseLinkPolicy` keeps web purchase links off on every storefront. "Manage account on the web" opens `/profile`.

The website can still sell Pro with Stripe. The apps do not link to that checkout. An App Store
subscription and a Stripe subscription are not linked yet: the usage API keeps using the Stripe plan.

**Account deletion (5.1.1(v))** is in Settings → *Delete account…*. It calls `delete-account`, which
cancels a Stripe subscription immediately. It does not cancel an App Store subscription; the paywall
and the delete confirmation say to cancel that in Settings → Apple ID → Subscriptions.

## 2. Review notes (paste into App Store Connect → App Review Information → Notes)

> Tokeny shows how much a user spends on AI APIs (OpenAI, Anthropic, OpenRouter). The app is a
> free, read-only companion to the web service at tokeny.martinpohl.cz: users connect their
> provider API keys on the web; the app shows totals, widgets, an Apple Watch complication and a
> Mac menu bar extra.
>
> Demo account (has ~75 days of sample data and the Pro plan):
>   Email: <DEMO_EMAIL>   Password: <DEMO_PASSWORD>
> Sign in with "Email" on the first screen. No API keys are needed; the data is sample data.
>
> Purchases: Tokeny Pro is an auto-renewable subscription sold with StoreKit (monthly and yearly).
> The paywall shows the price, period, auto-renewal terms, and links to the privacy policy, terms of
> service, and Apple's standard EULA. Restore Purchases is on that screen and in Settings. The app
> does not link to a website checkout. This build is for internal TestFlight only.
>
> Account deletion: Settings → Delete account… (removes the account and all data, and cancels a
> subscription bought on the web). An App Store subscription is canceled in Settings → Apple ID →
> Subscriptions.
>
> Privacy policy: https://tokeny.martinpohl.cz/privacy
> Support URL: https://tokeny.martinpohl.cz/en/support
> (Czech: https://tokeny.martinpohl.cz/support)

Fill in `<DEMO_EMAIL>` and `<DEMO_PASSWORD>` only in App Store Connect. Never put them in the repo.

## 3. Demo account

`scripts/app-review/seed-demo-user.mjs` creates or refreshes the account. It's idempotent, prints
no secrets, and the sample data comes from `scripts/app-review/demo-data.mjs`, tested in
`src/test/demo-seed.test.ts`.

```bash
# Run locally against production (Neon project "tokeny", the one the apps use):
export SITE_URL=https://tokeny.martinpohl.cz
export DATABASE_URL='postgresql://…'          # Neon connection string; shell only, never in .env or the repo
export DEMO_EMAIL=appreview@tokeny.martinpohl.cz
export DEMO_PASSWORD="$(openssl rand -base64 24)"; echo "$DEMO_PASSWORD" | pbcopy  # → App Store Connect
node scripts/app-review/seed-demo-user.mjs --dry-run   # 375 rows, Pro
node scripts/app-review/seed-demo-user.mjs             # or --free for a Free-plan account
unset DATABASE_URL DEMO_PASSWORD
```

What it creates:
- An email/password user (created through the normal sign-up; e-mail verification is off).
- 375 `activity_rows` (5 models × 75 days, ids `demo-app-review-*`).
- A Pro `subscriptions` row with the fake customer `cus_demo_app_review` and no Stripe subscription,
  valid for a year.
- No provider keys.

If the reviewer deletes the account, `delete-account` treats the fake customer as "missing" and
deletes normally. Re-run the script before the next submission. The demo mailbox address doesn't
need to receive mail. To change the password, re-run the script with a new `DEMO_PASSWORD`.

## 4. App Privacy ("nutrition label") answers

These are based on what the **apps** send: Sign in with Apple requests `.email` only; email/password
sign-in; usage totals are *read* from our API; there are no analytics or crash SDKs and no ads. They
match `apple/Resources/PrivacyInfo.xcprivacy`. If the web or the apps ever add analytics or crash
reporting, update both.

- **Do you or your third-party partners collect data from this app?** Yes.
- **Contact Info → Email Address:** collected. Linked to the user: yes. Tracking: no. Purpose: App
  Functionality.
- **Identifiers → User ID:** collected (Tokeny account id). Linked: yes. Tracking: no. Purpose:
  App Functionality.
- **Everything else** (Name, Phone, Location, Contacts, Health, Financial Info, Purchases, Usage Data
  / Product Interaction, Diagnostics, Browsing/Search History, User Content, Sensitive Info): **not
  collected by the app.** Notes:
  - *Purchases:* Apple sells the subscription. The app reads the StoreKit entitlement on device and
    does not send the receipt to Tokeny. Stripe data is collected by the **website**, outside this
    label. Do not mark Purchases as collected by the app unless a later build uploads receipts.
  - *Phone:* SMS login exists on the web only, not in the apps.
  - *Financial Info / User Content:* AI spend and provider keys are entered on the web. The app only
    displays totals. *(Unverified: if you'd rather be conservative, declaring "Other User Content →
    App Functionality, linked, no tracking" for the displayed usage data is harmless.)*
- **Tracking (ATT):** none, so no `NSUserTrackingUsageDescription` is needed.
- **Privacy policy URL:** `https://tokeny.martinpohl.cz/privacy`. It returns 404 today because
  `main` has no `vercel.json` (see `docs/domain-redirect.md`). **Deploy the stack first, or the URL
  check will fail.**

## 5. Before you submit (Martin)

1. Deploy the web stack so that `/privacy`, `/profile` and `/auth/callback` load on
   tokeny.martinpohl.cz.
2. Run the demo seed (section 3) and put the credentials in App Store Connect.
3. Create the App Store Connect subscriptions listed in the pull request before a device build can
   load prices outside the local StoreKit file. Keep the build on internal TestFlight. Do not submit.
4. Build in Xcode Cloud and test on TestFlight:
   - StoreKit local config (`Config/TokenyPro.storekit` on the Tokeny scheme): buy monthly, buy yearly, restore, manage.
   - A Czech sandbox account once the products exist (49 Kč / 399 Kč, disclosure in Czech).
   - Account link goes to `/profile` on every storefront.
   *(Unverified on a device: on Linux I could only unit-test the policy, not compile the SwiftUI
   targets.)*
5. Fill in the privacy answers from section 4 and paste the notes from section 2.
