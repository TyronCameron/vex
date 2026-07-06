---
vexid: fix-status-transition-enforcement-1
vextype: task
description: Status state machine doesn't actually reject invalid transitions
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

Confirmed by testing while writing the wiki: `vex set <task> --status done` succeeds with no error on a task whose status is `todo`, jumping straight past `doing`. Likewise `doing` back to `todo` succeeds silently. The `status` field is documented (and clearly intended, per `lib/statemachine.lua` and the states table in `core/taskdefinitions.lua`) to only allow `todo → doing → done`, but nothing actually blocks an out-of-order transition today.

Likely cause: `schema.statemachine`'s `prevalidate` (`lib/schema.lua`) returns `self.extra.statemachine.current` rather than the instance being set, and/or `self.extra.statemachine` is cached on the schema definition itself rather than per-task, so the same machine object (and its `current` pointer) may be getting reused/stale across different tasks and calls. Needs a proper look — this silently defeats the one piece of built-in workflow enforcement vex has.
