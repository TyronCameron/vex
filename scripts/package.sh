#!/usr/bin/env bash
set -euo pipefail
version="${1:?usage: scripts/package.sh <version> [outdir]}"
version="${version#v}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mkdir -p "${2:-$repo/dist}" && cd "${2:-$repo/dist}" && pwd)"
name="vex-$version"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/$name"
cp -R "$repo/src" "$stage/$name/src"
cp "$repo/install.sh" "$repo/install.ps1" "$repo/LICENSE" "$repo/README.md" "$stage/$name/"
printf "return '%s'\n" "$version" > "$stage/$name/src/version.lua"

(cd "$stage" && tar -czf "$out/$name.tar.gz" "$name" && zip -qr "$out/$name.zip" "$name")
(cd "$out" && sha256sum "$name.tar.gz" "$name.zip" > SHA256SUMS)
echo "$out/$name.tar.gz"
echo "$out/$name.zip"
