default:
	@just --list

test:
	#!/usr/bin/env bash
	status=0
	just test-unit || status=1
	just test-e2e || status=1
	just lint || status=1
	exit $status

test-unit *specs:
	test/unit/run.sh {{specs}}

test-e2e *specs:
	busted --run=e2e {{specs}}

lint:
	luacheck src test
	test/unit/mirror.sh

docs *args:
	site/build.sh {{args}}

install *args:
	sh install.sh {{args}}

package version *outdir:
	scripts/package.sh {{version}} {{outdir}}

bench:
	VEX_HOME=/nonexistent/vex-home luajit test/bench/run.lua
