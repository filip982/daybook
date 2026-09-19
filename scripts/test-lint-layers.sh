#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

make_feature() {
  local root="$1"
  mkdir -p "$root/Demo/Sources/Demo/UI" "$root/Demo/Sources/Demo/Providers" "$root/Demo/Sources/Demo/Store"
  printf 'struct OpenMeteoProvider {}\nprivate struct ForecastDTO {}\n' > "$root/Demo/Sources/Demo/Providers/OpenMeteoProvider.swift"
  printf 'struct LiveStore { let provider = OpenMeteoProvider() }\n' > "$root/Demo/Sources/Demo/Store/LiveStore.swift"
}

clean="$tmp/clean"
make_feature "$clean"
printf 'struct WeatherView { let title = "OpenMeteoProviders are hidden" }\n' > "$clean/Demo/Sources/Demo/UI/WeatherView.swift"
"$here/lint-layers.sh" "$clean" >/dev/null 2>&1 || { echo "FAIL: clean tree was rejected"; exit 1; }

dirty="$tmp/dirty"
make_feature "$dirty"
printf 'struct WeatherView { let provider = OpenMeteoProvider() }\n' > "$dirty/Demo/Sources/Demo/UI/WeatherView.swift"
if "$here/lint-layers.sh" "$dirty" >/dev/null 2>&1; then echo "FAIL: UI using a provider type was accepted"; exit 1; fi

dto="$tmp/dto"
make_feature "$dto"
printf 'struct WeatherView { var dto: ForecastDTO? }\n' > "$dto/Demo/Sources/Demo/UI/WeatherView.swift"
if "$here/lint-layers.sh" "$dto" >/dev/null 2>&1; then echo "FAIL: UI using a DTO was accepted"; exit 1; fi

noproviders="$tmp/noproviders"
mkdir -p "$noproviders/Demo/Sources/Demo/UI"
printf 'struct WeatherView {}\n' > "$noproviders/Demo/Sources/Demo/UI/WeatherView.swift"
"$here/lint-layers.sh" "$noproviders" >/dev/null 2>&1 || { echo "FAIL: target without Providers/ was rejected"; exit 1; }

noNames="$tmp/noNames"
mkdir -p "$noNames/Demo/Sources/Demo/UI" "$noNames/Demo/Sources/Demo/Providers"
printf 'extension Int { var doubled: Int { self * 2 } }\n' > "$noNames/Demo/Sources/Demo/Providers/Ext.swift"
printf 'struct WeatherView {}\n' > "$noNames/Demo/Sources/Demo/UI/WeatherView.swift"
"$here/lint-layers.sh" "$noNames" >/dev/null 2>&1 || { echo "FAIL: Providers/ with no type declarations was rejected"; exit 1; }

echo "test-lint-layers: ok"
