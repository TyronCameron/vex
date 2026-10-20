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
