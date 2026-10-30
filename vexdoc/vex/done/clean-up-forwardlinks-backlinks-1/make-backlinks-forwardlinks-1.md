---
vexid: make-backlinks-forwardlinks-1
vextype: atom
description: Make backlinks and forwardlinks transients
created: "2026-10-29 23:56:11"
modified: "2026-10-30 00:54:44"
status: done
---
Today `backlinks` and `forwardlinks` are focus operations (src/core/focus.lua: Focus:backlinks, Focus:forwardlinks). Make them transients on `task` in src/core/taskdefinitions.lua instead, each returning a list of vexids, so they read like any field (`--select backlinks`, `vex get --forwardlinks`). `backlinks` should still read `vexdex.backlinks[vexid]` for speed; `forwardlinks` is the vexids of the tasks this one links to (today a scan of vexdex.backlinks; consider whether the vexdex should store it). Document both in the transients table in [[02 Frontmatter schema]]. Verify: unit tests for both transients in test/unit/core/taskdefinitions_spec.lua and an e2e row in test/e2e/linking_spec.lua.