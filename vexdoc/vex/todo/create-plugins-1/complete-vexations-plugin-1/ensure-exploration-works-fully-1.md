---
vexid: ensure-exploration-works-fully-1
vextype: atom
description: Ensure exploration works fully
created: "2026-10-19 07:28:42"
modified: "2026-10-19 09:22:05"
status: todo
---

Check every promise the docs make about `exploration` and add e2e coverage for any that lacks it: the body must be empty and it can't have `children`. Decide whether an exploration needs its own status machine (the design journal's `unexplored` → `explored`, commented out at the bottom of `src/core/taskdefinitions.lua`).
