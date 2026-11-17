#!/bin/sh
# Xcode Cloud: runs before each xcodebuild action. ci_post_clone.sh already stamps
# CURRENT_PROJECT_VERSION before xcodegen. Write the same number again so the
# archive cannot fall back to the raw CI_BUILD_NUMBER (that reused build 3) or the
# local default. Do not run `agvtool new-version -all`: -all replaces
# $(CURRENT_PROJECT_VERSION) in Info.plist with a literal, and the widgets, Watch
# app and complication must keep the shared build setting.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH/apple"

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "CI_BUILD_NUMBER unset; keeping CURRENT_PROJECT_VERSION from the project"
  exit 0
fi

case "$CI_BUILD_NUMBER" in
  *[!0-9]*)
    echo "CI_BUILD_NUMBER is not an integer: $CI_BUILD_NUMBER" >&2
    exit 1
    ;;
esac

# Same offset as ci_post_clone.sh. Builds 1-3 of version 1.0.0 are already uploaded.
BUILD_NUMBER=$((CI_BUILD_NUMBER + 100))
PBXPROJ="Tokeny.xcodeproj/project.pbxproj"
tmp=$(mktemp)
sed -E "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};/g" "$PBXPROJ" > "$tmp"
mv "$tmp" "$PBXPROJ"

# grep -c exits 1 when the count is 0; don't let set -e abort before the check.
total=$(grep -c "CURRENT_PROJECT_VERSION = " "$PBXPROJ" || true)
updated=$(grep -c "CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};" "$PBXPROJ" || true)
if [ "$total" -eq 0 ] || [ "$total" -ne "$updated" ]; then
  echo "Failed to set CURRENT_PROJECT_VERSION on every target ($updated of $total)" >&2
  grep -n "CURRENT_PROJECT_VERSION" "$PBXPROJ" >&2 || true
  exit 1
fi

echo "Build number set to ${BUILD_NUMBER} (CI_BUILD_NUMBER ${CI_BUILD_NUMBER} + 100)"
