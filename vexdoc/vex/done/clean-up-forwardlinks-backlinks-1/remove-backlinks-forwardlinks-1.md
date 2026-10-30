---
vexid: remove-backlinks-forwardlinks-1
vextype: atom
description: Remove the backlinks and forwardlinks focus operations
created: "2026-10-29 23:56:11"
dependencies: 
  - "[[add-step-focus-operation-1]]"
modified: "2026-10-30 00:54:55"
status: done
---
Once `--step` exists, delete Focus:backlinks and Focus:forwardlinks and their entries in the operations list, and port every caller (e.g. TaskManager:remove's cascade uses `focus.focus(vexid):backlinks()`, and `arrange` uses Focus:forwardlinks) to `:step('backlinks')` / `:step('forwardlinks')`. Make `--tree` and `--reversetree` work over them (`--tree forwardlinks` follows links transitively; `--reversetree backlinks` is the same walk the other way) and cover that with tests. Update the flag tables in [[01 CLI reference]] and [[05 Getting into focus]], the method list in [[05 Configuring focuses]], and the CLAUDE.md Focus paragraph. Verify: just test.