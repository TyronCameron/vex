#!/usr/bin/env bash
set -euo pipefail
site="$(cd "$(dirname "$0")" && pwd)"
theme_version="v3.3.1"

if [ ! -d "$site/themes/dark-theme-editor" ]; then
	git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$theme_version" https://github.com/JingWangTW/dark-theme-editor.git "$site/themes/dark-theme-editor"
fi

rm -rf "$site/content"
mkdir "$site/content"
obsidian-export --no-git "$site/../vexdoc" "$site/content"

frontmatter() {
	local name title weight
	name="$1"
	title="${name#[0-9][0-9] }"
	weight=$([[ "$name" =~ ^([0-9]+)\  ]] && echo "$((10#${BASH_REMATCH[1]}))" || echo 100)
	[ "$title" = "Home" ] && weight=1
	printf -- '---\ntitle: "%s"\nweight: %d\n---\n' "${title//\"/\\\"}" "$weight"
}

find "$site/content" -name '*.md' -print0 | while IFS= read -r -d '' page; do
	{ frontmatter "$(basename "$page" .md)"; cat "$page"; } > "$page.tmp"
	mv "$page.tmp" "$page"
done

find "$site/content" -mindepth 1 -type d -print0 | while IFS= read -r -d '' section; do
	frontmatter "$(basename "$section")" > "$section/_index.md"
done

hugo --source "$site" --minify "$@"
