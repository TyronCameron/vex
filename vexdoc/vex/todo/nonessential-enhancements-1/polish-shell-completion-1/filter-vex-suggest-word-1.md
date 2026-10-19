---
vexid: filter-vex-suggest-word-1
vextype: atom
description: Filter vex suggest by the word being completed
created: "2026-10-19 09:21:54"
modified: "2026-10-19 09:21:54"
status: todo
---

[[01 Installing vex]] says the completion script completes verbs, focuses, views, recipes and flags as you type. `vex suggest` returns every candidate whatever has been typed (`vex suggest 2 vex set --st` lists every field), and the bash script puts that straight into `COMPREPLY`, as does the PowerShell one, so those shells offer everything. Filter candidates by the word being completed in `src/plugin/vexcomplete.lua` and test it in `test/unit/plugin/vexcomplete_spec.lua`.
