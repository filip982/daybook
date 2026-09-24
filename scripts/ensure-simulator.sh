#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ensure-simulator: $1" >&2; exit 1; }

destination="${1:?usage: ensure-simulator.sh '<xcodebuild destination>'}"
name="$(sed -n 's/.*name=\([^,]*\).*/\1/p' <<<"$destination")"
os="$(sed -n 's/.*OS=\([^,]*\).*/\1/p' <<<"$destination")"
[ -n "$name" ] && [ -n "$os" ] || fail "destination needs name= and OS=: $destination"

runtime="com.apple.CoreSimulator.SimRuntime.iOS-${os//./-}"

xcrun simctl list runtimes
xcrun simctl list runtimes | grep -F "iOS $os " || fail "runtime iOS $os is not installed"

if ! xcrun simctl list devices available "$runtime" | grep -F "$name (" >/dev/null; then
  echo "ensure-simulator: creating '$name' on $runtime"
  xcrun simctl create "$name" "$name" "$runtime"
fi

xcrun simctl list devices available "$runtime"
