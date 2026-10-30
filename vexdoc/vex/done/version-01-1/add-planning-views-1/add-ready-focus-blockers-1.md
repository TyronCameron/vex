---
vexid: add-ready-focus-blockers-1
vextype: atom
description: Add ready focus and blockers transient
created: "2026-10-28 07:36:05"
modified: "2026-10-30 03:20:23"
status: done
---
Add a `blockers` transient (a task's dependencies that are not final, src/core/taskdefinitions.lua) and a `ready` focus (unfinished tasks with no blockers, src/core/focus.lua). Documented in [[02 Frontmatter schema]] and [[01 CLI reference]]. Verify: `vex focus ready` lists only tasks that can be started now (test/e2e/lifecycle_spec.lua).