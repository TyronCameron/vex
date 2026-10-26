#!/bin/sh
# Install vex: sh install.sh [--uninstall]
# PREFIX (default ~/.local) gets lib/vex and bin/vex; VEX_VERSION picks a release when downloading.
set -eu

prefix="${PREFIX:-$HOME/.local}"
repo="TyronCameron/vex"

if [ "${1:-}" = "--uninstall" ]; then
	rm -rf "$prefix/lib/vex" "$prefix/bin/vex"
	echo "Removed vex from $prefix"
	exit 0
fi

command -v luajit >/dev/null 2>&1 || {
	echo "vex needs LuaJIT: https://luajit.org/" >&2
	exit 1
}

here="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$here/src/vex.lua" ]; then
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT
	version="${VEX_VERSION:-}"
	if [ -z "$version" ]; then
		version="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest")"
		version="${version##*/}"
	fi
	version="${version#v}"
	curl -fsSL "https://github.com/$repo/releases/download/v$version/vex-$version.tar.gz" | tar -xz -C "$tmp" --strip-components=1
	here="$tmp"
fi

rm -rf "$prefix/lib/vex"
mkdir -p "$prefix/lib" "$prefix/bin"
cp -R "$here/src" "$prefix/lib/vex"
chmod +x "$prefix/lib/vex/vex"
ln -sf "$prefix/lib/vex/vex" "$prefix/bin/vex"

echo "Installed vex $("$prefix/bin/vex" version) to $prefix"
case ":$PATH:" in
*":$prefix/bin:"*) ;;
*) echo "Add $prefix/bin to your PATH to run vex." ;;
esac
