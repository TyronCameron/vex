---
vexid: fix-vex-get-crashing-list-fields-1
vextype: task
description: Fix vex get crashing on list fields
created: "2026-10-17 02:11:47"
modified: "2026-10-17 21:13:10"
status: done
---
`vex get <vexid> --children` (or any field holding a list, such as `dependencies`, `options` or the `ancestors` transient) crashes with an `Internal error`: `Task:tostring` in `src/core/task.lua` passes each value straight to `table.concat`, which only takes strings and numbers. Seen on main before transients existed. List values need a printable form (e.g. comma-separated, matching how list flags are written).