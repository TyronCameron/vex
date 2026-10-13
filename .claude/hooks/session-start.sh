#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

missing=()
for pkg in luajit luarocks just lua-busted; do
  dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if [ ${#missing[@]} -gt 0 ]; then
  apt-get update -qq || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
fi

# apt's busted runs under PUC Lua 5.1; run it under LuaJIT instead so tests match the real runtime.
cat > /usr/local/bin/busted <<'WRAP'
#!/bin/sh
exec luajit /usr/bin/busted "$@"
WRAP
chmod +x /usr/local/bin/busted

# .busted enables coverage, which needs LuaCov. It isn't in apt, and luarocks.org may be
# blocked by the environment's network policy, so this is best-effort.
if ! luajit -e 'require "luacov"' >/dev/null 2>&1; then
  luarocks --lua-version=5.1 install luacov >/dev/null 2>&1 \
    || echo "session-start: could not install luacov; run busted with --no-coverage" >&2
fi

chmod +x "$CLAUDE_PROJECT_DIR/src/vex"
