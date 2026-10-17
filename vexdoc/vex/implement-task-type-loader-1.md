---
vexid: implement-task-type-loader-1
vextype: task
description: Load custom task types from .vex/tasks
created: "2026-07-06 12:00:00"
modified: "2026-10-14 22:16:53"
status: done
---
Fixed. The new core/extensions.lua runs every .lua file in .vex/tasks with task and schema in scope (via setfenv), so a file just calls task:task 'bug':extends 'task' { schema = ... }. Files load in path order, so a parent type must sort before its children. A broken file throws bad-extension.