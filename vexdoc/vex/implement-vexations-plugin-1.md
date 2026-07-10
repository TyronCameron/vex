---
vexid: implement-vexations-plugin-1
vextype: task
description: Build the vexations plugin
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`config.lua`'s default `plugins.vexations = true` references a plugin that doesn't exist — no `vexations` file under `src/plugin` or `src/default`. Per the design journal, this should be the opinionated bundle of the 4 task types (exploration/abstract/decision/atom) as an optional layer on top of the plain `task` type.
