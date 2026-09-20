#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
main_ref="${2:-main}"

fail() { echo "tag-release: $1" >&2; exit 1; }

[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must look like 1.2.3, got '$version'"
tag="v$version"
git rev-parse --verify --quiet "refs/tags/$tag" >/dev/null && fail "tag $tag already exists"

previous="$(git describe --tags --abbrev=0 --match 'v*' "$main_ref" 2>/dev/null || true)"
range="$main_ref"
[ -n "$previous" ] && range="$previous..$main_ref"

summary="$(git log --no-merges --reverse --format='- %s' "$range")"
[ -n "$summary" ] || fail "no commits since ${previous:-the start}"

printf 'Daybook %s\n\n%s\n' "$version" "$summary" | git tag -a "$tag" -F - "$main_ref"

git tag -l --format='%(contents)' "$tag"
echo "Created $tag on $main_ref. Push it with: git push origin $tag"
