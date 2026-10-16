---
vexid: fix-folder-path-focuses-1
vextype: task
description: Fix folder path focuses
created: "2026-10-14 22:19:34"
modified: "2026-10-16 02:05:05"
status: done
---
`namedfocus.from_folder_path` (`src/core/focus.lua`) inserts `namedfocus.from_file_path(path)` for each file it walks: a Focus object built from the folder path, not the task. A folder focus therefore returns focus objects instead of tasks. It should look up each walked file's task. `recursive_dir_walk` also passes bare names from `lfs.readdir` to `lfs.attributes`; check that those resolve against the folder.