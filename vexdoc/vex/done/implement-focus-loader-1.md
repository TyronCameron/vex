---
vexid: implement-focus-loader-1
vextype: task
description: Load custom named focuses from .vex/focuses
created: "2026-07-06 12:00:00"
modified: "2026-10-14 22:17:41"
status: done
---
Fixed. core/extensions.lua also runs .vex/focuses/*.lua with focus (the Focus class) in scope, so a file just calls focus.register_focus('name', function() ... end). Saved focuses replay by name, so they keep working.