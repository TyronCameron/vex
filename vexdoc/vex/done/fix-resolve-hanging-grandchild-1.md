---
vexid: fix-resolve-hanging-grandchild-1
vextype: task
description: Fix resolve hanging on grandchild task types
created: "2026-10-17 22:26:26"
modified: "2026-10-17 22:27:37"
status: done
---
`TaskManager:resolve` (`src/core/task.lua`) built the ancestor chain with `while parents[1].parent` but looked up `parents[#parents].parent`. For a type two levels below `task`, such as a `.vex/tasks` type extending `atom`, it kept inserting the same parent and never returned. It now looks up `parents[1].parent`, as `schemaof` and `transientof` already did.