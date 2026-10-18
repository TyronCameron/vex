---
vexid: implement-inline-plugin-1
vextype: task
description: Build the inline mode plugin
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`config.lua`'s default `plugins.inline = true` references a plugin that doesn't exist — no `inline` file under `src/plugin` or `src/default`. Build the `#vex Description` inline-tag tracking and the `open`/`inline` verbs described in the design journal (Vex.md's "Watch mode / plugin" section).
