#!/usr/bin/env bash
set -euo pipefail

app="${1:-ios/build/DerivedData/Build/Products/Debug-iphonesimulator/Daybook.app}"
plist="$app/Info.plist"

fail() { echo "verify-bundle: $1" >&2; exit 1; }

[ -d "$app" ] || fail "app not found at $app"

[ "$(plutil -extract CFBundleIdentifier raw "$plist")" = "com.blue-studio.daybook" ] \
  || fail "wrong bundle identifier"
[ "$(plutil -extract NSLocationWhenInUseUsageDescription raw "$plist")" = "Shows the weather where you are right now." ] \
  || fail "wrong or missing location usage string"
[ "$(plutil -extract ITSAppUsesNonExemptEncryption raw "$plist")" = "false" ] \
  || fail "ITSAppUsesNonExemptEncryption must be false"
[ "$(plutil -extract MinimumOSVersion raw "$plist")" = "18.0" ] \
  || fail "minimum OS must be 18.0"
[ -f "$app/PrivacyInfo.xcprivacy" ] || fail "privacy manifest missing from bundle"
plutil -lint "$app/PrivacyInfo.xcprivacy" >/dev/null || fail "privacy manifest is not a valid plist"

echo "verify-bundle: ok"
