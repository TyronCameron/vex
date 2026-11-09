---
vexid: enable-disable-standalone-1
vextype: atom
description: Enable and disable standalone plugins from config
created: "2026-10-19 09:21:53"
modified: "2026-11-04 02:09:32"
status: done
parent: "[[make-vex-configurable-config-1]]"
---

`Plugin:enable`, `Plugin:disable` and `Plugin:reload` exist and are documented in [[Plugin architecture]], but nothing calls them: every file in `src/plugin` always loads. Let `config.lua` turn standalone plugins on and off (e.g. `plugins = { vexcomplete = false }`), so a disabled plugin's verbs and errors are not registered. The old `plugins.inline = true` default mentioned in [[implement-inline-plugin-1]] is the kind of key this would read.

`plugins = { name = false }` now switches a standalone plugin off before it loads. The vexations types were split out into `src/plugin/vexations.lua` to make that possible ([[move-vexations-task-types-1]]), so `plugins = { vexations = false }` leaves only `task`.
