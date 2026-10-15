---
vexid: stop-resolve-normalising-twice-1
vextype: task
description: Stop resolve normalising twice
created: "2026-10-14 22:19:34"
modified: "2026-10-14 22:19:34"
status: todo
---
`normalise` in `src/core/task.lua` calls `vextype.schema.prevalidate(vextype.schema, task, context)` once unprotected, then again inside `pcall`. Every prevalidate step runs twice per resolve. Any error in the first call escapes as a `bug` instead of `resolution-failed-normalisation`. Drop the first call.