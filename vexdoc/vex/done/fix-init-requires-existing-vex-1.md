---
vexid: fix-init-requires-existing-vex-1
vextype: task
description: Fix vex init crashing outside an existing .vex tree
created: "2026-07-06 12:00:00"
modified: "2026-10-14 22:13:17"
status: done
---
Fixed. src/vex.lua already skips loading plugins for init, so vex init works in a fresh directory with no .vex above it (checked by hand).