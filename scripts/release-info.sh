#!/usr/bin/env bash
set -euo pipefail

tag="${1:-}"
main_ref="${2:-origin/main}"

fail() { echo "release-info: $1" >&2; exit 1; }

[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "tag must look like v1.2.3, got '$tag'"
commit="$(git rev-parse --verify --quiet "refs/tags/$tag^{commit}")" || fail "tag $tag does not exist"
git merge-base --is-ancestor "$commit" "$main_ref" || fail "tag $tag is not on $main_ref"

echo "VERSION=${tag#v}"
echo "BUILD=$(git rev-list --count "$commit")"
