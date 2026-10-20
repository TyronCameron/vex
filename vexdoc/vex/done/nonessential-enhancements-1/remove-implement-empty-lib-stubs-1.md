---
vexid: remove-implement-empty-lib-stubs-1
vextype: atom
description: Remove or implement the empty lib stubs
created: "2026-10-19 09:21:54"
modified: "2026-10-20 09:48:36"
status: done
---

`src/lib/dag.lua`, `src/lib/state.lua` and `src/lib/tree.lua` are empty `return {}` stubs left from the design journal's code plan ([[Vex]]). Nothing requires them: dependencies and children are walked by `Focus:tree`, and status by `lib.statemachine`. Delete them, or give them a purpose and a unit spec.
