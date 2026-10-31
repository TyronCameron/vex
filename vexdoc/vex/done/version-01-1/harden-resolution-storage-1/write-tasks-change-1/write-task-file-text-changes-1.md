---
vexid: write-task-file-text-changes-1
vextype: atom
description: Write a task file only when its text changes
created: "2026-10-31 04:50:58"
modified: "2026-10-31 04:51:03"
status: done
---
`TaskManager:resolveall` wrote every cascaded task whether or not it changed, and never wrote the tasks it was asked to resolve, so derived and normalised values reached the index but not the file. Now `resolveall` writes every task it resolved, and `TaskManager:write` renders the task (`taskformat.render`, new in `src/default/obsidian.lua`) and skips the write when the file already holds that text. The redundant `write` calls in `add`, `set`, `recipe`, `remove` and `delete` are gone. See [[Resolution pipeline]]. Verified by `test/e2e/storage_spec.lua` (files keep their bytes and mtime through resolves; `vex resolve <vexid>` writes a normalised `due`) and `test/e2e/dogfood_spec.lua`, whose snapshot now covers the nested backlog folders.