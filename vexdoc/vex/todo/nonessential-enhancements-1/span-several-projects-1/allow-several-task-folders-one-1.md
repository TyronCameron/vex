---
vexid: allow-several-task-folders-one-1
vextype: atom
description: Allow several task folders in one config
created: "2026-10-19 20:55:58"
modified: "2026-10-19 20:55:58"
status: todo
---

The design journal ([[Vex]], "Nesting") suggests an array of task folders in config. Today `taskfolder` is one path, and `TaskManager:reindexall`, `TaskManager:find` and `default.grouppath` all assume a single root. Accept a list (`taskfolder = {'backlog', 'docs/decisions'}`) while keeping a plain string working. Decide which folder a new task goes into: the first one, or one picked by a field. Update [[01 Configuring vex (config.lua)]].
