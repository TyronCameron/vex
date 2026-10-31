---
vexid: check-modified-date-used-vex-1
vextype: atom
description: "Check that modified date is used correctly in vex resolve, otherwise consider vex resolve all vs vex resolve updated"
created: "2026-10-19 08:02:07"
modified: "2026-10-31 04:51:10"
status: done
---
Answered by the atoms under [[write-tasks-change-1]]: `modified` now moves only when a task's fingerprint changes, and `vex resolve all` resolves only the files that changed (the `updated` focus), with `--force` for a full rebuild.