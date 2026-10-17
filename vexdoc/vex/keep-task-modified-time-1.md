---
vexid: keep-task-modified-time-1
vextype: task
description: "Keep each task's modified time when reindexing"
created: "2026-10-16 23:11:59"
modified: "2026-10-17 22:11:45"
status: done
---
TaskManager:reindexall resolves every task read from disk, and the modified field is a schema.derive that always returns os.time(). So vex resolve all stores the rebuild time as every task's modified in the index, while the task files keep their real modified time. The index no longer mirrors the files, and anything that compares modified (the updated focus, sorting by modified) sees every task as just changed. Resolving a task read from disk should keep its stored modified, and only a real change (add/set) should bump it.