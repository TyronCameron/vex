---
vexid: fix-two-adds-one-description-1
vextype: atom
description: Fix two adds with one description colliding before resolve
created: "2026-11-07 11:27:12"
modified: "2026-11-07 11:27:25"
status: done
---
`TaskManager:add` asked the tagger for a free vexid against `vexdex.index` only, so two tasks with one description added in one command (a recipe) both got `-1` and the second threw `task-already-exists`. It now also counts the tasks in memory. Tested in `test/unit/core/task_spec.lua`.