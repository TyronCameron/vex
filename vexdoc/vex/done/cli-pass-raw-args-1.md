---
vexid: cli-pass-raw-args-1
vextype: task
description: CLI should pass raw args
created: 1779228684
modified: 1783815043
status: done
---
Fixed. `CLI:run` now keeps the original raw string it was invoked with (before verb-name removal or tokenizing) and stashes it as `args.raw` on the parsed `Arguments` table it passes to the verb - so any verb can reach the exact, unsplit text a user typed after `vex`, alongside the already-tokenized positional/flag view. No built-in verb consumes it yet; it's there for verbs (built-in or user-defined) that want to do their own parsing. Covered by a new test in `test/unit/lib/cli_spec.lua`.