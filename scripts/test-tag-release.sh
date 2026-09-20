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

git commit --quiet --allow-empty -m "Add the project"
git commit --quiet --allow-empty -m "Add the weather model"

"$here/tag-release.sh" 0.1.0 >/dev/null
expected=$'Daybook 0.1.0\n\n- Add the project\n- Add the weather model'
actual="$(git tag -l --format='%(contents)' v0.1.0)"
[ "$actual" = "$expected" ] || { echo "FAIL: first tag message was: $actual"; exit 1; }
[ "$(git rev-parse 'v0.1.0^{commit}')" = "$(git rev-parse main)" ] || { echo "FAIL: tag is not on the tip of main"; exit 1; }

git checkout --quiet -b develop
git commit --quiet --allow-empty -m "Add the store"
git commit --quiet --allow-empty -m "Add the release job"
git checkout --quiet main
git merge --quiet --no-ff -m "Merge develop" develop
git checkout --quiet develop

"$here/tag-release.sh" 0.2.0 >/dev/null
expected=$'Daybook 0.2.0\n\n- Add the store\n- Add the release job'
actual="$(git tag -l --format='%(contents)' v0.2.0)"
[ "$actual" = "$expected" ] || { echo "FAIL: second tag message was: $actual"; exit 1; }
[ "$(git rev-parse 'v0.2.0^{commit}')" = "$(git rev-parse main)" ] || { echo "FAIL: second tag is not on the tip of main"; exit 1; }

reject() {
  if "$here/tag-release.sh" "$1" >/dev/null 2>&1; then echo "FAIL: $2 was accepted"; exit 1; fi
}

reject 0.2.0 "an existing tag"
reject v0.3.0 "a version with the v prefix"
reject 0.3 "a two-part version"
reject "" "an empty version"
reject 0.3.0 "a release with no new commits"

echo "test-tag-release: ok"
