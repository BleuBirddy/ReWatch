#!/bin/sh
# Cuts the Mac app icon sizes (16 to 1024 px) from Tools/AppIcon-mac.png,
# which make-icon.swift writes as its optional second output.
set -e
src="$(dirname "$0")/AppIcon-mac.png"
out="$(dirname "$0")/../ReWatch/Resources/Assets.xcassets/AppIcon.appiconset"
for px in 16 32 64 128 256 512 1024; do
  sips -z $px $px "$src" --out "$out/mac-$px.png" >/dev/null
done
