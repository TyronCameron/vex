---
vexid: detect-task-files-changed-disk-1
vextype: atom
description: Detect task files changed on disk
created: "2026-10-31 04:50:58"
modified: "2026-10-31 22:02:19"
status: done
---
The `updated` focus compared each task's `modified` with `vexdex.modified`, which was set to the time the vexdex loaded, so it was always empty, and the index only learned of hand edits from `vex resolve all`. Now the vexdex stamps each task file's mtime (`VexDex:unsafe_stamp`) and `VexDex:updated` lists every file under `taskfolder` with its mtime in one shell call (`lfsext.mtimes`), returning the indexed tasks whose files were edited, moved, made unreadable or deleted (the `updated` focus) and the files it doesn't know. Before `show`, `get`, `set`, `view`, `remove` and `resolve` read their focus, `focus_pop_args` in `src/core/verbs.lua` resolves its updated tasks; resolving a task whose file is gone or unreadable drops it from the index. See [[The index]] and [[05 Getting into focus]]. Verified by `test/e2e/storage_spec.lua`, `test/unit/core/vexdex_spec.lua` and the `files changed on disk` block of `test/unit/core/task_spec.lua`.