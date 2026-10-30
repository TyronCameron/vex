---
vexid: implement-config-defaults-1
vextype: atom
description: "Choose each plugin slot's active member from config.lua"
created: "2026-07-06 12:00:00"
modified: "2026-10-30 07:09:14"
status: todo
---

Ensure that every plugin is swappable and changeable through the config file.

Rescoped: `default.tasktype` is already wired ([[wire-default-tasktype-rename-1]]). What remains is the plugin half. `src/vex.lua` registers six enums (`tagger`, `taskpath`, `taskformat`, `sortdata`, `frontmatter`, `body`) and `Plugin:select` can switch the active member, but nothing reads the config to call it, so [[Plugin architecture]]'s "switch the active member" is only reachable by editing vex itself.

Read a `plugins` table from `config.lua` (e.g. `plugins = { taskformat = 'json' }`), call `plugin:select` for each slot before anything calls `plugin:get` (note `core.task` and `core.view` call `plugin:get` when they load, and `core.config` needs the vexdex), and throw a named error for an unknown slot or member.
