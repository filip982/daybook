#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ensure-simulator: $1" >&2; exit 1; }

destination="${1:?usage: ensure-simulator.sh '<xcodebuild destination>'}"
name="$(sed -n 's/.*name=\([^,]*\).*/\1/p' <<<"$destination")"
os="$(sed -n 's/.*OS=\([^,]*\).*/\1/p' <<<"$destination")"
[ -n "$name" ] && [ -n "$os" ] || fail "destination needs name= and OS=: $destination"

runtime="com.apple.CoreSimulator.SimRuntime.iOS-${os//./-}"

xcrun simctl list runtimes | grep -F "iOS $os " || fail "runtime iOS $os is not installed"

udid="$(xcrun simctl list devices available -j | ruby -rjson -e '
  device = JSON.parse(STDIN.read).dig("devices", ARGV[0]).to_a.find { |d| d["name"] == ARGV[1] }
  puts device["udid"] if device
' "$runtime" "$name")"

if [ -z "$udid" ]; then
  echo "ensure-simulator: creating '$name' on $runtime"
  udid="$(xcrun simctl create "$name" "$name" "$runtime")"
fi

xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl list devices "$runtime"

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "DESTINATION=id=$udid" >> "$GITHUB_ENV"
fi
echo "ensure-simulator: $udid ready"
