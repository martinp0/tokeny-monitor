#!/bin/sh
# Copy the shared price catalog into the Swift package.
# The file has to live inside the package so SwiftPM can bundle it, and it is a
# real copy (not a symlink) so Xcode Cloud and XcodeGen can see it.
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
src="$root/shared/pricing/model-prices.json"
dest="$root/apple/TokenyKit/Sources/TokenyCore/Resources/model-prices.json"
if [ ! -f "$src" ]; then
  echo "Missing shared price catalog: $src" >&2
  exit 1
fi
mkdir -p "$(dirname "$dest")"
cp "$src" "$dest"
