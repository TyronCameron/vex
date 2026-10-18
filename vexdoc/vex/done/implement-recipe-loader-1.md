---
vexid: implement-recipe-loader-1
vextype: task
description: Load custom recipes from .vex/recipes
created: "2026-07-06 12:00:00"
modified: "2026-10-14 22:17:16"
status: done
---
Fixed. core/extensions.lua also runs .vex/recipes/*.lua with recipe in scope, so a file just calls recipe:recipe 'name' { add = function(task, taskproperties) ... end }.