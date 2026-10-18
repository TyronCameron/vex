---
vexid: fix-status-transition-enforcement-1
vextype: task
description: "Status state machine doesn't actually reject invalid transitions"
created: "2026-07-06 12:00:00"
modified: "2026-10-13 08:44:38"
status: done
---

Fixed. The `statemachine` schema (`core/taskdefinitions.lua`) used to cache one machine on `self.extra`, shared by every task, and seed it from `context.task.status`, which `TaskManager:set` had already overwritten. Now `set` builds a new task instead of changing the indexed one, `resolve` passes the indexed version as `context.previous`, and `prevalidate` builds a fresh `statemachine.new` from that previous status. `todo -> done` and `doing -> todo` now fail with `resolution-failed-validation`. An unchanged status is always valid, so `vex resolve all` accepts whatever is on disk, and a new task with no status gets `todo`. `lib/statemachine.lua`'s `preprocess` copies state definitions instead of mutating them, so a machine can be built more than once from the same definition. `version-01-1` got `children: []` so `vex resolve all` completes. Covered by `test/unit/core/taskdefinitions_spec.lua`, `test/unit/core/task_spec.lua` and an e2e test in `test/e2e/lifecycle_spec.lua`.
