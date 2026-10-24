#!/usr/bin/env bash
set -uo pipefail
export VEX_HOME=/nonexistent/vex-home
repo="$(cd "$(dirname "$0")/../.." && pwd)"
specs=("$@")
if [ ${#specs[@]} -eq 0 ]; then
	mapfile -t specs < <(find "$repo/test/unit" -name '*_spec.lua' | sort)
fi
failed=()
for spec in "${specs[@]}"; do
	spec="$(cd "$(dirname "$spec")" && pwd)/$(basename "$spec")"
	echo "== ${spec#"$repo/"}"
	tmp=$(mktemp -d)
	(cd "$tmp" && "$repo/src/vex" init >/dev/null \
		&& busted --helper="$repo/test/unit/load.lua" --config-file="$repo/.busted" "$spec") \
		|| failed+=("${spec#"$repo/"}")
	rm -rf "$tmp"
done
if [ ${#failed[@]} -gt 0 ]; then
	printf 'failed: %s\n' "${failed[@]}" >&2
	exit 1
fi
