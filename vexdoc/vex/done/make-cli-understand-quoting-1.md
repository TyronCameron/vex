---
vexid: make-cli-understand-quoting-1
vextype: task
description: make CLI understand quoting
created: "2026-07-10 22:12:14"
modified: "2026-07-12 00:10:43"
status: done
---

Fixed. `lib/cli.lua`'s `parse_args` used to split on bare whitespace (`%S+`), so a shell-quoted flag value containing a space (e.g. `--filter status:"not done"`) got torn back into two tokens the moment `vex.lua` rejoined `arg` with `table.concat(arg, " ")` and handed it back to the parser. It now tokenizes with a small POSIX-style scanner: single quotes are fully literal, double quotes allow `\"`/`\\`/`\$`/`` \` `` escapes, a bare backslash escapes the next character outside quotes, and a quoted segment glues onto adjacent unquoted text into one word (so `status:"not done"` reads back as `status:not done`, and the classic `don'\''t` idiom reads back as `don't`).

That alone wasn't enough, since `vex.lua` was reassembling `arg` with a plain space-join before parsing, which throws away the word boundaries the shell already established. `CLI:rawify(argv)` now quotes any word that needs it (containing whitespace, a quote character, or a backslash) before joining, so the round trip through `parse_args` reproduces the original argv exactly. `vex.lua` calls `cli:rawify(arg)` instead of `table.concat(arg, " ")`. Covered by new tokenizer tests in `test/unit/lib/cli_spec.lua`.
