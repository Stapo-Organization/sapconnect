#!/bin/bash
# Build the release app and put it on a paired iPhone.
#
# Why this exists instead of a plain `flutter build ios --release` + install:
# `package:objective_c` reaches the bundle through Flutter's *native assets*
# pipeline (build/native_assets/ios/objective_c.framework), which is embedded
# WITHOUT being re-signed — CocoaPods' own embed script never sees it. It stays
# ad-hoc signed, the device refuses the whole app with
#
#     Failed to verify code signature of .../objective_c.framework
#     (0xe8008014) — ApplicationVerificationFailed
#
# so this signs any ad-hoc framework with the app's own identity and re-seals
# the bundle (top level only — the Live Activity extension keeps its signature).
#
# Usage: tool/install_device.sh [device-udid]
set -euo pipefail

cd "$(dirname "$0")/.."
APP=build/ios/iphoneos/Runner.app

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  # Column position is not stable — device and model names hold spaces — so
  # pick the field that IS a UUID off the first paired row.
  DEVICE=$(xcrun devicectl list devices 2>/dev/null \
    | awk '/available \(paired\)/ {
        for (i = 1; i <= NF; i++)
          if ($i ~ /^[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}$/) { print $i; exit }
      }')
fi
[ -n "$DEVICE" ] || { echo "No paired device. Unlock the iPhone and put it on this Wi-Fi." >&2; exit 1; }

echo "▸ building…"
flutter build ios --release

IDENTITY=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=\(Apple Development:.*\)/\1/p' | head -1)
[ -n "$IDENTITY" ] || { echo "The build is unsigned — check the signing team in Xcode." >&2; exit 1; }

ENTITLEMENTS=$(mktemp -t zb-entitlements)
trap 'rm -f "$ENTITLEMENTS"' EXIT
codesign -d --entitlements - --xml "$APP" > "$ENTITLEMENTS" 2>/dev/null

resealed=0
for framework in "$APP"/Frameworks/*.framework; do
  if codesign -dvv "$framework" 2>&1 | grep -q '^Signature=adhoc'; then
    echo "▸ signing $(basename "$framework") (ad-hoc from the native-assets pipeline)"
    codesign --force --sign "$IDENTITY" --timestamp=none "$framework"
    resealed=1
  fi
done

if [ "$resealed" = 1 ]; then
  echo "▸ re-sealing the bundle"
  codesign --force --sign "$IDENTITY" --timestamp=none \
    --entitlements "$ENTITLEMENTS" --generate-entitlement-der "$APP"
fi

codesign --verify --deep --strict "$APP"

echo "▸ installing on $DEVICE…"
xcrun devicectl device install app --device "$DEVICE" "$APP" | grep -E "bundleID|App installed"
xcrun devicectl device info apps --device "$DEVICE" 2>/dev/null | grep -i zooboxi
