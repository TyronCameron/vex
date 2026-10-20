#!/usr/bin/env bash
set -euo pipefail
site="$(cd "$(dirname "$0")" && pwd)"
docs="$site/content/docs"

rm -rf "$site/content"
mkdir -p "$docs"
obsidian-export --no-git "$site/../vexdoc" "$docs"
mv "$docs/Home.md" "$docs/Introduction.md"

title() {
	case "$1" in
		_index) echo "Documentation" ;;
		Vex) echo "Design journal" ;;
		*) echo "${1#[0-9][0-9] }" ;;
	esac
}

icon() {
	case "$1" in
		Introduction) echo "home" ;;
		"01 Getting started") echo "rocket_launch" ;;
		"02 Features") echo "terminal" ;;
		"03 Configuration") echo "tune" ;;
		"04 Technical documentation") echo "engineering" ;;
		Vex) echo "history_edu" ;;
	esac
}

weight() {
	case "$1" in
		Introduction) echo 1 ;;
		[0-9][0-9]\ *) echo "$((10#${1:0:2} + 1))" ;;
		*) echo 100 ;;
	esac
}

summary() {
	case "$1" in
		"01 Getting started") echo "Install vex, create your first tasks and build whole structures with recipes." ;;
		"02 Features") echo "Every command, field, task type and view." ;;
		"03 Configuration") echo "Configure a project, and extend vex from its .vex folder." ;;
		"04 Technical documentation") echo "How plugins, the index and events work under the hood." ;;
		Vexdex) echo "What lives in .vex/vexdex: the index and the event logs." ;;
		Vex) echo "The original design notes behind vex, including ideas not built yet." ;;
	esac
}

description() {
	awk '
		/^```/ { exit }
		/^[[:space:]]*(#|\||>|-|\*|!)/ { if (seen) exit; next }
		/^[[:space:]]*$/ { if (seen) exit; next }
		{ seen = 1; text = text (text ? " " : "") $0 }
		END { print text }
	' "$1" | sed -E 's/\[[0-9]{2} /[/g; s/\[([^]]*)\]\([^)]*\)/\1/g; s/^([^.!?]*[.!?])([[:space:]].*)?$/\1/; s/\\/\\\\/g; s/"/\\"/g'
}

frontmatter() {
	local name="$1" page="$2" ico desc
	printf -- '---\ntitle: "%s"\nweight: %s\n' "$(title "$name")" "$(weight "$name")"
	ico="$(icon "$name")"
	[ -n "$ico" ] && printf 'icon: "%s"\n' "$ico"
	desc="$(summary "$name")"
	[ -z "$desc" ] && [ -n "$page" ] && desc="$(description "$page")"
	[ -n "$desc" ] && printf 'description: "%s"\n' "$desc"
	printf -- '---\n'
}

callouts() {
	awk '
		function close_callout() {
			print "{{% alert context=\"" context "\" %}}"
			print text
			print "{{% /alert %}}"
			callout = 0
		}
		match($0, /^ ?> \\\[![A-Za-z]+\\\]/) {
			kind = substr($0, RSTART, RLENGTH)
			sub(/.*!/, "", kind)
			sub(/\\\]$/, "", kind)
			kind = tolower(kind)
			context = kind == "warning" ? "warning" : kind == "tip" ? "success" : kind == "danger" ? "danger" : "info"
			heading = substr($0, RSTART + RLENGTH + 1)
			text = heading == "" ? "" : "**" heading "**"
			pending = ""
			callout = 1
			next
		}
		callout && /^ ?>/ { sub(/^ ?> ?/, ""); text = text (text == "" ? "" : " ") $0; next }
		callout { close_callout() }
		/^ ?> ?$/ { if (pending) print pending; pending = $0; next }
		pending != "" { print pending; pending = "" }
		{ print }
		END { if (callout) close_callout() }
	'
}

hovertables() {
	awk '
		/^```/ { fence = !fence }
		!fence && /^\|/ && !table { print "{{< table \"table-hover\" >}}"; table = 1 }
		table && !/^\|/ { print "{{< /table >}}"; table = 0 }
		{ print }
		END { if (table) print "{{< /table >}}" }
	'
}

linktitles() {
	sed -E 's/\[[0-9]{2} ([^]]*)\]\(/[\1](/g'
}

find "$docs" -name '*.md' -print0 | while IFS= read -r -d '' page; do
	{ frontmatter "$(basename "$page" .md)" "$page"; callouts < "$page" | hovertables | linktitles; } > "$page.tmp"
	mv "$page.tmp" "$page"
done

frontmatter _index "" > "$docs/_index.md"

find "$docs" -mindepth 1 -type d -print0 | while IFS= read -r -d '' section; do
	frontmatter "$(basename "$section")" "" > "$section/_index.md"
done

printf -- '---\ntitle: "vex"\n---\n' > "$site/content/_index.md"

hugo --source "$site" --minify "$@"
