---
vexid: filter-resolve-updated-files-add-1
vextype: atom
description: Filter resolve all to updated files and add
created: "2026-10-31 04:50:58"
dependencies: 
  - "[[detect-task-files-changed-disk-1]]"
modified: "2026-10-31 04:51:04"
status: done
---
`vex resolve all` now resolves only the files that changed since vex last saw them, taking in new files and forgetting deleted ones, and `vex resolve [focus]` only the tasks in the focus that changed. `--force` resolves the whole focus, and `vex resolve all --force` rebuilds the index from every file (`TaskManager:reindexall`), for when `config.lua` or a task type changed. See [[01 CLI reference]]. Verified by the `--force` case in `test/e2e/grouping_spec.lua` and the rows in `test/e2e/smoke_spec.lua`.