---
vexid: leave-empty-focus-vex-remove-1
vextype: atom
description: Leave an empty focus after vex remove
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
`vex remove` cleared the focus, so a later bare command failed with `no-focus`. It now saves the `none` focus.