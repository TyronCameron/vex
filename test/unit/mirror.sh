#!/usr/bin/env bash
set -uo pipefail
repo="$(cd "$(dirname "$0")/../.." && pwd)"
missing=0
while IFS= read -r src; do
	rel="${src#"$repo/src/"}"
	case "$rel" in vex.lua|lib/binser.lua) continue ;; esac
	[ "$(tr -d '[:space:]' < "$src")" = "return{}" ] && continue
	spec="test/unit/${rel%.lua}_spec.lua"
	if [ ! -f "$repo/$spec" ]; then
		echo "src/$rel has no unit spec: add $spec" >&2
		missing=1
	fi
done < <(find "$repo/src" -name '*.lua' | sort)
exit $missing
