---
vexid: decide-one-project-holds-several-1
vextype: atom
description: Decide how one project holds several task folders
created: "2026-10-20 09:47:59"
modified: "2026-10-30 03:17:28"
status: todo
---

Needs more thinking before any code. The design journal ([[Vex]], "Nesting") suggests one project spanning several task folders. Today `taskfolder` is one path, and `TaskManager:reindexall`, `TaskManager:find` and `default.grouppath` all assume a single root.

Options to weigh:

- A list of task folders in `config.lua` (`taskfolder = {'backlog', 'docs/decisions'}`). This raises the question of which folder a new task goes into.
- More `.vex` folders: each folder that holds tasks gets its own `.vex`, and a project brings them together.

Write the decision into this body, then break the build into atoms under [[allow-several-task-folders-one-1]].
