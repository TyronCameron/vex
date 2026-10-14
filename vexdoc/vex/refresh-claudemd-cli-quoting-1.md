---
vexid: refresh-claudemd-cli-quoting-1
vextype: task
description: Refresh CLAUDE.md CLI quoting notes
created: "2026-10-14 22:19:35"
modified: "2026-10-14 22:19:35"
status: todo
---
CLAUDE.md's CLI section still says flag values cannot contain spaces because the CLI rejoins and re-splits `arg`. `lib.cli` now has a quote-aware `tokenize` and `CLI:rawify`, so `--vexbody "two words"` survives. The comment in `test/e2e/lifecycle_spec.lua` about the `T` separator dodging "the CLI's space-splitting flag bug" is stale too. Check whether `due` still needs `T`, and update both.