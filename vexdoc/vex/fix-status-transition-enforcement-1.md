---
vexid: fix-status-transition-enforcement-1
vextype: task
description: "Status state machine doesn't actually reject invalid transitions"
created: "2026-07-06 12:00:00"
modified: "2026-10-13 08:44:38"
status: done
---

Fixed. The `statemachine` schema (`core/taskdefinitions.lua`) no longer caches one machine on `self.extra` shared by every task. `TaskManager:resolve` now reads the task's file as it is on disk and passes it to the schemas as `context.persisted`; `validate` builds a fresh machine from that persisted status and checks the new one against it, so `todo -> done` and `doing -> todo` fail with `resolution-failed-validation`. An unchanged status is always valid, so `vex resolve all` accepts whatever status is on disk, and a new task with no status defaults to `todo`. `lib/statemachine.lua`'s `preprocess` now copies the state definitions rather than mutating them, so a machine can be built more than once from the same table. `version-01-1` now has `children: []` so `vex resolve all` completes. Covered by `test/unit/core/taskdefinitions_spec.lua` and an e2e test in `test/e2e/lifecycle_spec.lua`.
