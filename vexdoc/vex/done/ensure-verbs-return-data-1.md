---
vexid: ensure-verbs-return-data-1
vextype: task
description: Ensure all verbs return data and do not print
created: 1779226066
modified: 1783815043
status: done
---
Fixed. Every verb (`show`, `focus`, `view`, `remove`, `get`, `recipe` in `core/verbs.lua`, plus the built-in `help` verb in `lib/cli.lua`) previously called `print`/`pretty.print` directly, mid-verb, instead of returning a value. They now build up a list of output lines and `return table.concat(lines, "\n")` (via a small `join_lines` helper that returns `nil` rather than `""` when there's nothing to say, so a verb that produced no output before still produces none). `CLI:run` already printed a verb's string/number return value once at the top level - that single `print` call reproduces the exact same terminal output as the old per-line `print`/`pretty.print` calls, since each of those always emitted its own trailing newline.

Terminal output is unchanged (verified via the e2e suite and manual runs), but every verb is now independently callable through `CLI:call` and testable/composable without capturing stdout.