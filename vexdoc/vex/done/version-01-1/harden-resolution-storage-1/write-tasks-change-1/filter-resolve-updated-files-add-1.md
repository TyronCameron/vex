---
vexid: filter-resolve-updated-files-add-1
vextype: atom
description: Filter resolve all to updated files and add
created: "2026-10-31 04:50:58"
dependencies: 
  - "[[detect-task-files-changed-disk-1]]"
modified: "2026-10-31 22:02:19"
status: done
---
`vex resolve all` (`TaskManager:reindexall`) now resolves only the indexed tasks whose files changed since vex last saw them, and reads in the files the vexdex doesn't know (new, or moved by hand), and `vex resolve [focus]` only the tasks in the focus that changed. `--force` resolves the whole focus, and `vex resolve all --force` clears the index first so every file is read, for when `config.lua` or a task type changed. See [[01 CLI reference]]. Verified by the `--force` case in `test/e2e/grouping_spec.lua` and the rows in `test/e2e/smoke_spec.lua`.