# Xcode Cloud for the Tokeny apps

The scripts below are what a future Xcode Cloud workflow would run. No workflow is configured in this
repository, and as of the 8 Nov 2026 read-only App Store Connect check there was no Tokeny app record
to attach one to. The repository has
no `.xcodeproj`: `apple/ci_scripts/ci_post_clone.sh` installs XcodeGen and generates it from
`apple/project.yml`. Xcode Cloud finds `ci_scripts/` because it sits next to the generated project.

## What the scripts do

| Script | When | What |
| --- | --- | --- |
| `ci_post_clone.sh` | after the clone | `brew install xcodegen`, `xcodegen generate`, copies `TokenyKit/Package.resolved` into the project and runs `xcodebuild -resolvePackageDependencies` (Xcode Cloud disables automatic package resolution) |
| `ci_pre_xcodebuild.sh` | before every build action | `agvtool new-version -all $CI_BUILD_NUMBER`, so every upload has a unique build number and the extensions match their apps |

Marketing version stays `MARKETING_VERSION` in `project.yml` (1.0.0). Bump it there for a new release.

## One-time setup (on the Mac)

1. **App Store Connect → Apps → +** create two app records (bundle IDs must exist first, see
   `apple/README.md` → One-time setup, or build once in Xcode with automatic signing):
   - *Tokeny* (iOS), bundle ID `cz.martinpohl.tokeny`, SKU `cz.martinpohl.tokeny`. Scheme `Tokeny`
     embeds the iPhone widgets (`cz.martinpohl.tokeny.widgets`). It does not embed the Watch app.
     Primary language English (`en`), from `developmentLanguage` in `apple/project.yml`. Czech (`cs`)
     is an additional string-catalog localization.
   - *Tokeny* (macOS), bundle ID `cz.martinpohl.tokeny.mac`, SKU `tokeny-mac`.
   Both: category Finance, price Free.
   If both platforms should be one store listing, create one app and add macOS as a platform instead;
   a universal purchase needs the same bundle ID on both, which this project does not use.
2. Locally: `brew install xcodegen && cd apple && xcodegen generate && open Tokeny.xcodeproj`.
3. In Xcode, **Integrate → Create Workflow…**, choose the **Tokeny** product, connect GitHub
   (`martinp0/tokeny-monitor`) when asked and grant Xcode Cloud access to the repository.
4. Create the workflows below. Edit them in Xcode (Report navigator → Cloud → right-click the
   workflow → Edit Workflow) or in App Store Connect → Xcode Cloud.

### Workflow 1: "PR – build & test"

- **General:** name `PR – build & test`; *Restrict editing* on.
- **Environment:** Xcode *Latest Release* (26 or newer), macOS *Latest*. No environment variables or
  secrets needed (the only backend setting is the public web host in `apple/Config/Backend.xcconfig`).
- **Start conditions:** *Pull Request Changes*, source branch *Any*, target branch *Any*.
  *Files and folders:* start only when files in `apple/` or `server/usage-summary.ts` change.
  Turn *Auto-cancel builds* on.
- **Actions:**
  - *Test* → scheme **Tokeny**, platform iOS, destination *iPhone 17 (Latest iOS)*. Runs the
    TokenyKit tests (Swift Testing).
  - *Build* → scheme **TokenyMac**, platform macOS (catches Mac-only compile errors).
- **Post-actions:** none. GitHub shows the result as a check on the PR.

### Workflow 2: "main – TestFlight"

- **Start conditions:** *Branch Changes*, branch `main`, files in `apple/` (or *Any* file if you
  want every merge shipped).
- **Actions:**
  - *Archive* → scheme **Tokeny**, platform iOS, *Deployment preparation: TestFlight (Internal
    Testing Only)* until App Review is done, then *TestFlight and App Store*.
  - *Archive* → scheme **TokenyMac**, platform macOS, same distribution option.
- **Post-actions:** *TestFlight Internal Testing* → add your internal group to both the iOS and the
  macOS archive. *Notify* → e-mail on failure.

## Signing

Automatic signing is on (`CODE_SIGN_STYLE: Automatic`, team `GR59NF57R2`). Xcode Cloud manages the
certificates and provisioning profiles itself; there is nothing to upload and no secret to add. On
the first archive it may ask in App Store Connect to confirm the capabilities the project requests
(App Groups, and Keychain sharing on the iPhone app and widgets). The project does not request
Sign in with Apple. Approving capabilities is an account change and is outside this repository.

## Checklist before the first TestFlight build

- [ ] App IDs and the App Group exist (README → One-time setup, step 1)
- [ ] Neon Auth Apple provider configured and accepts the two bundle IDs (unverified whether Neon Auth supports extra native audiences)
- [ ] `usage-summary` deployed with JWT support
- [ ] Both App Store Connect app records exist
- [ ] Workflows created, first PR build green
- [ ] Privacy policy page live at `/privacy`, URL entered in App Store Connect
- [ ] Support URL live at `/en/support` (Czech at `/support`), entered in App Store Connect
- [ ] App Privacy questionnaire: E-mail Address + User ID, linked to the user, App Functionality, no tracking
- [ ] Export compliance: `ITSAppUsesNonExemptEncryption = NO` is already set (HTTPS only)
