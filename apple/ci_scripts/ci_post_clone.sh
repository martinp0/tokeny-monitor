#!/bin/sh
# Xcode Cloud: runs right after the clone, before Xcode resolves packages.
# The .xcodeproj is not committed, so generate it from project.yml here.
#
# Build number. The value App Store Connect stores is CI_BUILD_NUMBER. The
# archive export writes that into export options as buildNumber, including when
# manageAppVersionAndBuildNumber is false. Archive - iOS run 6 logged
# CURRENT_PROJECT_VERSION 106 and uploaded CFBundleVersion 6, so an offset
# never ships. Do not add one. The next run is 7, which is already above the
# last uploaded build (6).
#
# Still copy CI_BUILD_NUMBER into the single shared CURRENT_PROJECT_VERSION
# before xcodegen. The app, widgets, Watch app and Watch complication then
# compile with the same CFBundleVersion the export uploads. Info.plist must
# keep $(CURRENT_PROJECT_VERSION). Do not run `agvtool new-version -all`: -all
# replaces that reference with a literal, and an embedded bundle can ship a
# different build (the mismatch fixed in #59, fbcd56f).
# Local builds do not set CI_BUILD_NUMBER and keep 1 from project.yml.
# MARKETING_VERSION stays the one value in project.yml (1.0.0) for every target.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH/apple"

# The Swift package bundles shared/pricing/model-prices.json. Copy it before Xcode resolves the package.
../scripts/sync-shared-pricing.sh

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  case "$CI_BUILD_NUMBER" in
    *[!0-9]*)
      echo "CI_BUILD_NUMBER is not an integer: $CI_BUILD_NUMBER" >&2
      exit 1
      ;;
  esac
  tmp=$(mktemp)
  sed -E "s/^([[:space:]]*)CURRENT_PROJECT_VERSION: .*/\\1CURRENT_PROJECT_VERSION: \"${CI_BUILD_NUMBER}\"/" project.yml > "$tmp"
  mv "$tmp" project.yml
  if ! grep -q "^[[:space:]]*CURRENT_PROJECT_VERSION: \"${CI_BUILD_NUMBER}\"" project.yml; then
    echo "Failed to set CURRENT_PROJECT_VERSION in project.yml" >&2
    exit 1
  fi
  # One key, shared by every target. A per-target copy is how versions drift.
  settings=$(grep -c "^[[:space:]]*CURRENT_PROJECT_VERSION:" project.yml || true)
  if [ "$settings" -ne 1 ]; then
    echo "project.yml must set CURRENT_PROJECT_VERSION once (found ${settings})" >&2
    exit 1
  fi
  echo "CURRENT_PROJECT_VERSION=${CI_BUILD_NUMBER} (CI_BUILD_NUMBER, no offset)"
fi

marketing=$(grep -c "^[[:space:]]*MARKETING_VERSION:" project.yml || true)
if [ "$marketing" -ne 1 ]; then
  echo "project.yml must set MARKETING_VERSION once (found ${marketing})" >&2
  exit 1
fi

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
xcodegen generate --spec project.yml

# Info.plist must keep the build-setting references. agvtool -all used to replace
# them with a literal, so an embedded widget could ship a different CFBundleVersion
# than the app and App Store validation would fail.
for plist in \
  iOS/Info.plist \
  macOS/Info.plist \
  Generated/TokenyWidgets-Info.plist \
  Generated/TokenyWatch-Info.plist \
  Generated/TokenyWatchWidgets-Info.plist
do
  if [ ! -f "$plist" ]; then
    echo "Missing generated Info.plist: $plist" >&2
    exit 1
  fi
  if ! grep -q '$(CURRENT_PROJECT_VERSION)' "$plist"; then
    echo "$plist does not set CFBundleVersion to \$(CURRENT_PROJECT_VERSION)" >&2
    exit 1
  fi
  if ! grep -q '$(MARKETING_VERSION)' "$plist"; then
    echo "$plist does not set CFBundleShortVersionString to \$(MARKETING_VERSION)" >&2
    exit 1
  fi
done

# Xcode Cloud builds with automatic package resolution disabled, so the project needs a
# Package.resolved. The app's only package is the local TokenyKit, whose pins are committed in
# TokenyKit/Package.resolved; start from those and let xcodebuild confirm or update them.
RESOLVED_DIR="Tokeny.xcodeproj/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$RESOLVED_DIR"
cp TokenyKit/Package.resolved "$RESOLVED_DIR/Package.resolved"
xcodebuild -resolvePackageDependencies -project Tokeny.xcodeproj -scheme Tokeny
