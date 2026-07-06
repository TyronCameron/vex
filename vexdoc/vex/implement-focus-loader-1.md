---
vexid: implement-focus-loader-1
vextype: task
description: Load custom named focuses from .vex/focuses
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`.vex/focuses` is created by `vex init` but nothing reads it — only the 4 hardcoded named focuses in `core/focus.lua` (all, none, updated, prev) exist. Auto-register a Lua file per named focus, following the same shape as `Focus.register_focus`.
