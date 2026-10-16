---
vexid: fix-unknownvextype-naming-nil-1
vextype: task
description: Fix unknown-vextype naming nil type
created: "2026-10-15 13:00:30"
modified: "2026-10-16 02:05:04"
status: done
---
`TaskManager:resolve` (`src/core/task.lua`) throws `unknown-vextype` with `vextype`, which is nil at that point, instead of `task.vextype`. `vex add Hello there --vextype nope` prints "Type = nil" rather than naming `nope`.