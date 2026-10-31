---
vexid: make-resolve-linear-1
vextype: atom
description: Make resolve all linear
created: "2026-10-31 05:55:58"
dependencies: 
  - "[[stop-lineage-scanning-task-1]]"
modified: "2026-10-31 05:56:04"
status: todo
---
vex resolve all on unlinked tasks takes 7s at 1k, 121s at 5k and 472s at 10k: quadratic, because every resolve pays the O(n) scans in [[stop-lineage-scanning-task-1]], and it resolves each task twice (2,024 resolves for 1,007 tasks). Fix after that atom, check resolve all resolves each task once, and verify the scaling with a flat project of task files (see test/bench/run.lua).