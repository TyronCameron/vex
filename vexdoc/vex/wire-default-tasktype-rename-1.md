---
vexid: wire-default-tasktype-rename-1
vextype: task
description: Wire default.tasktype and rename users to taskowners
created: "2026-10-18 04:24:27"
modified: "2026-10-18 04:25:04"
status: done
---
`vex init` wrote `default.taskformat`, `default.view`, `default.dataformat`, `default.option` and `plugins.*` into every config, but nothing read them. They are gone from the default config, this repo's config and the docs. `default.tasktype` is wired: `TaskManager:add` gives a task without a `vextype` the configured one, falling back to `task`. `users` is renamed to `taskowners`, the names `owner` may take.