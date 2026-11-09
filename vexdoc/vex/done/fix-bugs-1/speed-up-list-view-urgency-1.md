---
vexid: speed-up-list-view-urgency-1
vextype: atom
description: Speed up the list view and urgency
created: "2026-11-04 05:05:56"
modified: "2026-11-04 05:05:56"
status: done
parent: "[[fix-bugs-1]]"
---
`vex view list` took about 30s on 163 tasks: `Focus:orderby` read transients inside the sort comparator and every `urgency` read re-ranked all open tasks. Now `orderby` reads each field once, `due` defaults to the earliest due of the open tasks that depend on it (src/core/taskdefinitions.lua, [[02 Frontmatter schema]]), and `urgency` is a count over stored dates. Verify: just test, and the `vex view all list` row of just benchmark.