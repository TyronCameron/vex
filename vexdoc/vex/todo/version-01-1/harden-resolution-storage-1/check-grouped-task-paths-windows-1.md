---
vexid: check-grouped-task-paths-windows-1
vextype: atom
description: Check grouped task paths on Windows
created: "2026-10-17 08:37:12"
modified: "2026-10-30 03:17:28"
status: todo
---
Grouped task paths (`paths.groupby`, see [[group-task-files-into-1]]) are only tested on Linux. On Windows, two things in `src/core/task.lua` are unverified:

- `lfs.mkdir` shells out to `mkdir "<path>"`, where `<path>` mixes the backslashes of `vexdex.path` with the forward slashes vex joins paths with. cmd may not create the nested folders.
- `tidy` removes emptied folders with `os.remove`, which can't delete a directory on Windows, so empty group folders would pile up.

Run the grouping e2e cases (`test/e2e/grouping_spec.lua`) on Windows and fix whatever fails.
