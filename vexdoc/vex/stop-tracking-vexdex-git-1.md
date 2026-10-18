---
vexid: stop-tracking-vexdex-git-1
vextype: task
description: Stop tracking the vexdex in git
created: "2026-10-17 22:06:15"
modified: "2026-10-17 22:06:20"
status: done
---
The index, backlinks and focus in `.vex/vexdex/` are derived from the task files, so tracking them in git only produced merge conflicts on every branch. `.vex/vexdex/` is now ignored. After a clone or pull, `vex resolve all` rebuilds it, and `VexDex:ensureindex` creates the folder when it is missing.