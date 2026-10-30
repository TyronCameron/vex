---
vexid: ignore-files-not-readable-vex-1
vextype: atom
description: Ignore files that are not readable vex tasks
created: "2026-10-30 07:09:09"
modified: "2026-10-30 07:09:14"
status: done
---
A note without a `vexid` in the task folder (e.g. one made by TaskNotes) crashed `vex resolve all` with an Internal error, and a file with broken frontmatter stopped it with `unreadable-task`. `TaskManager:readfrompath` now gives nil for both, so `resolve all` ignores them; `unreadable-task` is gone. This reverses item 1 of [[double-check-cascading-resolving-1]] at the user's request. Documented in [[The index]]; verified in `test/unit/core/task_spec.lua`, `test/e2e/storage_spec.lua` and `test/e2e/resolution_spec.lua`.