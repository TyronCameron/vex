---
vexid: implement-view-loader-1
vextype: task
description: Load custom views from .vex/views
created: "2026-07-06 12:00:00"
modified: "2026-10-14 22:18:06"
status: done
---
Fixed. core/extensions.lua also runs .vex/views/*.lua with view in scope, so a file just calls view:view 'name' { display = function(focus, flags) ... end }.