#!/bin/sh
# Xcode Cloud: runs right after the clone, before Xcode resolves packages.
# The .xcodeproj is not committed, so generate it from project.yml here.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH/apple"

# The Swift package bundles shared/pricing/model-prices.json. Copy it before Xcode resolves the package.
../scripts/sync-shared-pricing.sh

# Version 1.0.0 builds 1-3 are already in App Store Connect (ITMS-90189 rejected
# another build 3). Stamp 100 + CI_BUILD_NUMBER into the spec before xcodegen so
# every target, including widgets and the Watch app, inherits the same value.
# Local builds do not set CI_BUILD_NUMBER and keep the number in project.yml.
# Same offset as ci_pre_xcodebuild.sh.
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  case "$CI_BUILD_NUMBER" in
    *[!0-9]*)
      echo "CI_BUILD_NUMBER is not an integer: $CI_BUILD_NUMBER" >&2
      exit 1
      ;;
  esac
  BUILD_NUMBER=$((CI_BUILD_NUMBER + 100))
  tmp=$(mktemp)
  sed -E "s/^([[:space:]]*)CURRENT_PROJECT_VERSION: .*/\\1CURRENT_PROJECT_VERSION: \"${BUILD_NUMBER}\"/" project.yml > "$tmp"
  mv "$tmp" project.yml
  if ! grep -q "^[[:space:]]*CURRENT_PROJECT_VERSION: \"${BUILD_NUMBER}\"" project.yml; then
    echo "Failed to set CURRENT_PROJECT_VERSION in project.yml" >&2
    exit 1
  fi
  echo "CURRENT_PROJECT_VERSION=${BUILD_NUMBER} (CI_BUILD_NUMBER ${CI_BUILD_NUMBER} + 100)"
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
