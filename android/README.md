# Tokeny pro Android

První nativní Android aplikace Tokeny. Je to Kotlin a Jetpack Compose, ne WebView. V téhle verzi je přehled útraty, rozpad podle poskytovatelů a modelů a detail rozpočtu s pražským odhadem **jen jako označená ukázka**. Živý účet se nepřipojuje.

Anglicky totéž níž, včetně sestavení a toho, co je živé, ukázka, nebo chybí.

## Co tahle verze umí

- Import CSV přes systémový výběr souboru. Náhled, pak uložení do soukromého souboru aplikace. Smazání importu. Formáty a limity: [docs/local-csv.md](docs/local-csv.md).
- Úvod bez přihlášení a vysvětlení, proč účet nejde otevřít.
- Tři vzory, oddělené od importu: účet s útratou (tvar Pro), účet Free (bez rozpočtu a odhadu) a prázdný účet.
- Přepínání Kč / USD. Dny ve vzoru jsou v `Europe/Prague`.
- Telefon: spodní lišta. Širší okno (vnitřní displej Foldu, tablet): postranní lišta a dva sloupce. Rozhoduje šířka okna, ne úhel pantu.
- Stavy: načítání, prázdná ukázka, chyba poškozeného souboru, offline. Offline pořád ukáže ukázku, protože je v aplikaci.
- Čeština je výchozí text, angličtina je v `values-en`.

Ukázka má nahoře pruh **UKÁZKA · Tohle nejsou tvoje útraty**. Nejde zavřít jinak než zavřením celé ukázky. Aplikace nevolá síť, neukládá heslo, cookie ani klíče k Anthropic, OpenAI nebo OpenRouteru a neotevírá platbu.

## Sestavení

Potřeba je JDK 21, compileSdk a targetSdk 37 (platforma `android-37.0`) a build-tools `36.0.0`. `minSdk` je 26. `ANDROID_HOME` stačí, `local.properties` do gitu nepatří.

```bash
cd android
./gradlew :core:test :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
```

Ladící APK: `app/build/outputs/apk/debug/app-debug.apk`. Podepisuje ho ladící klíč stroje, který v gitu není. CI je `.github/workflows/android.yml` a spouští se jen při změně `android/**`.

## English

Version `0.2.0` (`versionCode` 2), application id `cz.martinpohl.tokeny`.

The signed-out sample is still there and stays labeled. Real spend on the phone is a CSV the user picks and confirms. Parsing follows the web OpenRouter activity export and the Cursor / Grok Bot usage export. Days are Europe/Prague, including the DST boundaries. Amounts stay in USD. A connected Pro budget and forecast are not invented. See [docs/local-csv.md](docs/local-csv.md).

There is no working sign-in. See [docs/auth-and-backend.md](docs/auth-and-backend.md) for the checks against `https://tokeny.martinpohl.cz` on 8 Nov 2026 and the missing mobile contract. Samsung layout notes are in [docs/samsung-ux.md](docs/samsung-ux.md). Signing, Play, and monetization next steps are in [docs/signing-and-next-steps.md](docs/signing-and-next-steps.md). The API change this app needs, and does not implement, is [docs/api-coordination.md](docs/api-coordination.md).

The branch is cut from `main` at `5c775f6` (PR #41). There was no Android directory, branch, or pull request to extend. The Apple apps keep their own session-cookie client; this app does not copy that approach.
