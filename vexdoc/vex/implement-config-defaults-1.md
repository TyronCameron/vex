---
vexid: implement-config-defaults-1
vextype: task
description: Wire up config.lua's default.* and plugins.* keys
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`vex init`'s default `config.lua` writes a `default` table (taskformat, view, dataformat, option, tasktype) and a `plugins` table (vexations, inline), but nothing in the codebase reads any of these keys — only `taskfolder` is actually consulted (`core/task.lua`). Found while writing the wiki's Configuring vex (config.lua) page. At minimum, `default.view` should give `vex view <focus>` a fallback so a lone argument doesn't have to be read as the view name.
