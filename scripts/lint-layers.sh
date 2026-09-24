#!/usr/bin/env bash
set -euo pipefail

root="${1:-ios/Packages}"
status=0

for target in "$root"/*/Sources/*; do
  ui="$target/UI"
  providers="$target/Providers"
  [ -d "$ui" ] && [ -d "$providers" ] || continue

  names="$(grep -rhoE '(struct|class|enum|actor|protocol)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$providers" --include='*.swift' | awk '{print $2}' | sort -u || true)"

  for name in $names; do
    hits="$(grep -rlwF "$name" "$ui" --include='*.swift' | while read -r file; do
      sed -E 's/"([^"\\]|\\.)*"/""/g' "$file" | grep -nwF "$name" | sed "s|^|$file:|" || true
    done || true)"
    if [ -n "$hits" ]; then
      echo "$hits" >&2
      echo "error: UI/ must not name '$name', which is declared in Providers/ ($target)" >&2
      status=1
    fi
  done
done

exit $status
