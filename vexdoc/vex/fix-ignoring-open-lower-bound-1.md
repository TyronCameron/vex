---
vexid: fix-ignoring-open-lower-bound-1
vextype: task
description: Fix between ignoring an open lower bound
created: "2026-10-17 22:19:49"
modified: "2026-10-17 22:21:25"
status: done
---
`--between cost::9` should keep tasks with `cost <= 9`, but `split` in `src/core/focus.lua` dropped empty parts, so `9` became the lower bound. `split` now keeps empty parts and `Focus:between` treats an empty bound as open.