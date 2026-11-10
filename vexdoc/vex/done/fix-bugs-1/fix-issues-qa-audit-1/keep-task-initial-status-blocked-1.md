---
vexid: keep-task-initial-status-blocked-1
vextype: atom
description: Keep a task in its initial status while blocked
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
A task could be set `done` while its dependencies were open. `schema.unblocked` throws `blocked` when a task leaves its initial phase while a dependency isn't final. `vex set` now sets every task in its focus before resolving any, so finishing a task and its dependency together works in either order.