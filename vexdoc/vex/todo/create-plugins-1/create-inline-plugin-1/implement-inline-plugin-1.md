---
vexid: implement-inline-plugin-1
vextype: atom
description: "Create tasks from #vex tags with vex inline"
created: "2026-07-06 12:00:00"
modified: "2026-10-19 09:22:45"
status: todo
---

`config.lua`'s default `plugins.inline = true` references a plugin that doesn't exist — no `inline` file under `src/plugin` or `src/default`. Build the `#vex Description` inline-tag tracking and the `open`/`inline` verbs described in the design journal (Vex.md's "Watch mode / plugin" section).

Rescoped to the first step. [[01 CLI reference#Inline tags]] documents `vex inline <file>`: each `#vex`, `#abstract`, `#atom`, `#explore` or `#decision` tag in a text file becomes a task of that type, and the rest of the line works like `vex add` (description, then flags). Build that verb in an `inline` plugin under `src/plugin`, with e2e coverage. Rewriting tags, nesting and `vex open` are separate tasks under [[create-inline-plugin-1]].
