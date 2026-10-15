---
vexid: fix-file-path-focuses-1
vextype: task
description: Fix file path focuses
created: "2026-10-15 13:07:26"
modified: "2026-10-15 13:07:26"
status: todo
---
Found by the new e2e smoke test. `vex focus ./some-task-1.md` (or an absolute path to a task file) focuses on 0 vexes: `namedfocus.from_file_path` (`src/core/focus.lua`) strips the folders but keeps the `.md` extension, then looks `some-task-1.md` up in the index, which is keyed by vexid. It should find the task by its path (see also [[fix-folder-path-focuses-1]], which builds on this).