#!/bin/sh
# Xcode Cloud: runs before each xcodebuild action.
#
# ci_post_clone.sh already set the shared CURRENT_PROJECT_VERSION to
# CI_BUILD_NUMBER. Write that same number again so every configuration in the
# generated project matches, including a target still on the local default.
# Do not add an offset. Export sets buildNumber to CI_BUILD_NUMBER (run 6
# uploaded 6, not 106). The next run is 7, above the last uploaded build.
#
# Do not run `agvtool new-version -all`. -all replaces $(CURRENT_PROJECT_VERSION)
# in Info.plist with a literal, and the widgets, Watch app and complication
# must keep the shared build setting (ITMS-90189, #59 fbcd56f).
# MARKETING_VERSION is not modified; every target must already share one value.
set -eu

cd "$CI_PRIMARY_REPOSITORY_PATH/apple"

PBXPROJ="Tokeny.xcodeproj/project.pbxproj"
if [ ! -f "$PBXPROJ" ]; then
  echo "Missing ${PBXPROJ}; ci_post_clone.sh should have generated it" >&2
  exit 1
fi

if [ -n "${CI_BUILD_NUMBER:-}" ]; then
  case "$CI_BUILD_NUMBER" in
    *[!0-9]*)
      echo "CI_BUILD_NUMBER is not an integer: $CI_BUILD_NUMBER" >&2
      exit 1
      ;;
  esac
  BUILD_NUMBER=$CI_BUILD_NUMBER
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
  echo "CURRENT_PROJECT_VERSION=${BUILD_NUMBER} on ${updated} settings (CI_BUILD_NUMBER, no offset)"
else
  echo "CI_BUILD_NUMBER unset; keeping CURRENT_PROJECT_VERSION from the project"
  # One value per line. Do not delete newlines (tr -d '[:space:]' would glue
  # 1.0.0 and 1.0.1 into a single token and hide the mismatch).
  uniq=$(grep "CURRENT_PROJECT_VERSION = " "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION =[[:space:]]*"?([^";[:space:]]+)"?.*/\1/' | sort -u || true)
  n=$(printf '%s\n' "$uniq" | grep -c . || true)
  if [ "$n" -ne 1 ]; then
    echo "CURRENT_PROJECT_VERSION differs across the project" >&2
    grep -n "CURRENT_PROJECT_VERSION" "$PBXPROJ" >&2 || true
    exit 1
  fi
fi

# Same marketing version on every target (1.0.0 in project.yml). Not rewritten.
# Quotes are ignored so "1.0.0" and 1.0.0 count as one value.
muniq=$(grep "MARKETING_VERSION = " "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION =[[:space:]]*"?([^";[:space:]]+)"?.*/\1/' | sort -u || true)
mn=$(printf '%s\n' "$muniq" | grep -c . || true)
if [ "$mn" -ne 1 ]; then
  echo "MARKETING_VERSION differs across the project" >&2
  grep -n "MARKETING_VERSION" "$PBXPROJ" >&2 || true
  exit 1
fi
echo "MARKETING_VERSION=${muniq} shared by every target"

for plist in \
  iOS/Info.plist \
  macOS/Info.plist \
  Generated/TokenyWidgets-Info.plist \
  Generated/TokenyWatch-Info.plist \
  Generated/TokenyWatchWidgets-Info.plist
do
  if [ ! -f "$plist" ]; then
    echo "Missing Info.plist: $plist" >&2
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
