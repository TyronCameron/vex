
default:
	@just --list

test: test-unit test-e2e

test-unit:
	#!/usr/bin/env bash
	set -euo pipefail
	repo="$(pwd)"
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	(cd "$tmp" && "$repo/src/vex" init)
	(cd "$tmp" && busted --helper="$repo/test/unit/load.lua" --config-file="$repo/.busted" "$repo/test/unit")

test-e2e:
	busted --run=e2e

test-all:
	vex add Hello world