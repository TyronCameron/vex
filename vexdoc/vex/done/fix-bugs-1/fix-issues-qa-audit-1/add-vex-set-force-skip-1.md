---
vexid: add-vex-set-force-skip-1
vextype: atom
description: Add vex set --force to skip resolution
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
A finished task couldn't be reopened. `vex set <focus> --force --fields...` writes the fields as given without resolving, through `TaskManager:force` (with `pre`/`post-task-force` events), so `vex set x --force --status todo` reopens a task. See [[01 CLI reference]].