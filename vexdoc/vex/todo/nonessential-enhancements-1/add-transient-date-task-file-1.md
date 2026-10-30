---
vexid: add-transient-date-task-file-1
vextype: atom
description: Add a transient for the date a task file was last committed
created: "2026-10-19 20:55:58"
modified: "2026-10-30 03:17:28"
status: todo
---

The design journal ([[Vex]], "Schedules") lists commit dates among task dates. Add a `committed` transient: the time of the last git commit that touched the task's file (`git log -1 --format=%ct -- <path>`, using the `path` transient). It should be nil outside a git repository or for an uncommitted file. Because it shells out, make sure it only runs when read (e.g. `--select committed`), never on every resolve.
