---
vexid: move-modified-task-fingerprint-1
vextype: atom
description: Move modified only when a task fingerprint changes
created: "2026-10-31 04:50:57"
modified: "2026-10-31 04:51:03"
status: done
---
`modified` was a `schema.derive` reset on every resolve (`src/core/taskdefinitions.lua`), and `TaskManager:set` set it again, so every resolve, every no-op `set` and every cascade put a new `modified` into git. Now `modified` is a `schema.default`, and `TaskManager:resolvesingle` compares the task's fingerprint (`TaskManager:fingerprint`, an FNV-1a hash from `src/lib/hash.lua` of the rendered file without the fields in `config.fingerprint.exclude`) with the one the vexdex stamped (`VexDex:unsafe_stamp`, `files.bin`). Only a different fingerprint moves `modified`. See [[Resolution pipeline]]. Verified by `test/e2e/storage_spec.lua` (backdated tasks keep `modified` through resolves and no-op sets) and the `changes` block of `test/unit/core/task_spec.lua`.