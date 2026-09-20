#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

repo="$tmp/repo"
git init --quiet --initial-branch=main "$repo"
cd "$repo"
git config user.name test
git config user.email test@example.com
git config commit.gpgsign false
git config tag.gpgsign false

for n in 1 2 3; do git commit --quiet --allow-empty -m "main $n"; done
git tag v1.2.3
git tag v1.2
git tag v1.2.3-beta
git tag 1.2.3
git checkout --quiet -b side
git commit --quiet --allow-empty -m "side 1"
git tag v9.9.9
git checkout --quiet main
git commit --quiet --allow-empty -m "main 4"

out="$("$here/release-info.sh" v1.2.3 main)"
[ "$out" = $'VERSION=1.2.3\nBUILD=3' ] || { echo "FAIL: expected VERSION=1.2.3 and BUILD=3, got: $out"; exit 1; }

reject() {
  if "$here/release-info.sh" "$1" main >/dev/null 2>&1; then echo "FAIL: $2 was accepted"; exit 1; fi
}

reject v1.2 "a two-part version"
reject v1.2.3-beta "a pre-release suffix"
reject 1.2.3 "a tag without the v prefix"
reject v0.0.1 "a tag that does not exist"
reject v9.9.9 "a tag that is not on main"
reject "" "an empty tag"

message="$("$here/release-info.sh" v9.9.9 main 2>&1 >/dev/null || true)"
[ "$message" = "release-info: tag v9.9.9 is not on main" ] || { echo "FAIL: unexpected message: $message"; exit 1; }

echo "test-release-info: ok"
