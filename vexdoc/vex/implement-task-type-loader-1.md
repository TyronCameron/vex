---
vexid: implement-task-type-loader-1
vextype: task
description: Load custom task types from .vex/tasks
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`.vex/tasks` is created by `vex init` but nothing reads it — the 4 built-in types (abstract, decision, exploration, atom) are only registered in `core/taskdefinitions.lua`. Auto-register a `vextype` per file using the same `task:task 'name':extends 'parent' { schema = ... }` pattern.
