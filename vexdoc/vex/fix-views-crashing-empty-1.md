---
vexid: fix-views-crashing-empty-1
vextype: task
description: Fix views crashing on empty focus
created: "2026-10-15 13:03:38"
modified: "2026-10-16 02:05:04"
status: done
---
Found by the new view unit tests. With an empty focus (e.g. `vex view none csv`), the `csv` view crashes in `func.lua` (`pairs` on nil), `kanban` crashes in `view.lua` (`ipairs` on nil) and `singular` indexes a nil task. An empty focus should render an empty view, and `singular` should throw a usage error like it does for more than one task.