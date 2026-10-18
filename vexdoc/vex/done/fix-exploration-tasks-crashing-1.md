---
vexid: fix-exploration-tasks-crashing-1
vextype: task
description: Fix exploration tasks crashing on add
created: "2026-10-15 13:00:29"
modified: "2026-10-16 02:05:04"
status: done
---
Found by the e2e smoke test. `vex add Explore some options --vextype exploration` crashes with an Internal error: the `empty` schema (`src/lib/schema.lua`) takes `#instance` of a nil `vexbody`. An exploration with no body yet should either resolve or fail validation with a named error.