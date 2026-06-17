
default:
	@just --list

test:
	busted test

test-all:
	vex add Hello world