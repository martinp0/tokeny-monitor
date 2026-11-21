# On-device month summary

iPhone only, Tokeny Pro. The dashboard section is **AI month summary** / **AI shrnutí měsíce**.

The summary is a headline, the spend changes that matter, the top models and providers, and two or three saving tips. It is computed from the usage summary already on the phone (and from savings tips already loaded for that account). The model call does not start a request. Provider keys, the account id, and e-mail are not part of the prompt.

## Model

`FoundationMonthSummaryProvider` uses `SystemLanguageModel.default` and guided generation (`@Generable`). The screen checks `availability` and handles `deviceNotEligible`, `appleIntelligenceNotEnabled`, and `modelNotReady`. Language is separate: `supportsLocale`. Czech is not an Apple Intelligence language. A Czech device asks for an English summary when the model supports English. If English is not available either, or the model errors, the fixed template is shown. The template is Czech or English and does not call a model. The dashboard stays usable while a summary is prepared; the fixed text is on screen first.

`LocalAIProvider` is the seam for another on-device backend later. The planner, the prompt, and the template live in TokenyKit and are unit tested. The Foundation Models types are compiled only with the iOS app.

Watch and the widgets do not run this. Sending a generated paragraph to the watch would be a new payload, and the watch does not host the model session.

## China mainland

The app's China AIGC declaration is **No**. The summary, including the Pro teaser, is off when the StoreKit storefront country code is `CHN` or the device region is `CN`. That is `OnDeviceSummaryAvailability` in `apple/TokenyKit/Sources/TokenyCore/LocalAIProvider.swift`. The flag defaults to off for those two codes and on for every other storefront, including Hong Kong (`HKG`), Macau (`MAC`), and Taiwan (`TWN`). The on-device model object is not created while the storefront is unknown or when the gate is closed.

Pro follows the server plan, the same rule as the rest of the app (`UsageSummary.isPro`). A StoreKit entitlement that the server has not accepted yet does not unlock the summary. Someone who is not Pro sees the teaser and the existing paywall, except on the China mainland storefront, where the section is absent.
