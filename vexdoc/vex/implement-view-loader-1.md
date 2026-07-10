---
vexid: implement-view-loader-1
vextype: task
description: Load custom views from .vex/views
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`.vex/views` is created by `vex init` but nothing reads it — the 6 built-in views (csv, tabular, json, kanban, overview, singular) are only registered in `core/view.lua`. Auto-register a view per file using the `{ display = function(focus, flags) ... end }` shape `View:view` already expects.
