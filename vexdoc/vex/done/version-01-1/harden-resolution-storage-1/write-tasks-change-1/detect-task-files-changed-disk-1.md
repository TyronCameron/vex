---
vexid: detect-task-files-changed-disk-1
vextype: atom
description: Detect task files changed on disk
created: "2026-10-31 04:50:58"
modified: "2026-10-31 04:51:03"
status: done
---
The `updated` focus compared each task's `modified` with `vexdex.modified`, which was set to the time the vexdex loaded, so it was always empty, and the index only learned of hand edits from `vex resolve all`. Now `lfsext.mtimes` lists every file under `taskfolder` with its mtime in one shell call, the vexdex stamps each task's mtime, and `TaskManager:updated` (the `updated` focus) returns the tasks whose files were edited, added, moved, made unreadable or deleted. `TaskManager:refresh` resolves those and forgets (`TaskManager:forget`) the gone or unreadable ones, leaving their files. Before `show`, `get`, `set`, `view`, `remove` and `resolve` read their focus, `focus_pop_args` in `src/core/verbs.lua` refreshes it. See [[The index]] and [[05 Getting into focus]]. Verified by `test/e2e/storage_spec.lua` and the `refresh` block of `test/unit/core/task_spec.lua`.