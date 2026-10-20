---
vexid: move-vexations-task-types-1
vextype: atom
description: Move the vexations task types into a vexations plugin
created: "2026-10-19 09:21:53"
modified: "2026-10-19 09:21:53"
status: todo
---

[[03 Task types (and vexations)]] says "the vexations plugin adds four types", and [[Plugin architecture]] says `src/plugin` holds a `vexations` plugin. There is no such plugin: `exploration`, `abstract`, `decision` and `atom` (and the `abstract` recipe) are registered in `src/core/taskdefinitions.lua` next to the base `task` type. Move them into `src/plugin/vexations.lua`, keeping `task` and the transients in core, so the opinionated types can be disabled or replaced.
