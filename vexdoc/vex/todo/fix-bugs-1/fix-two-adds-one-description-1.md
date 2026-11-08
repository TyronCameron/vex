---
vexid: fix-two-adds-one-description-1
vextype: atom
description: Fix two adds with one description colliding before resolve
created: "2026-11-07 11:27:12"
modified: "2026-11-07 11:27:25"
status: todo
---
`TaskManager:add` asked the tagger for a free vexid against `vexdex.index` only, so two tasks with one description added in one command (a recipe) both got `-1` and the second threw `task-already-exists`. The built-in `repeat` and vexations recipes work around it by resolving each task as they add it, but a hand-written recipe like the `release` example in [[04 Configuring recipes]] would hit it with repeated descriptions. Fix it in `TaskManager:add` (`src/core/task.lua`) so a vexid held by an unresolved task in memory counts as taken, and test two same-description adds before a resolve in `test/unit/core/task_spec.lua`.