---
vexid: implement-recipe-loader-1
vextype: task
description: Load custom recipes from .vex/recipes
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`.vex/recipes` is created by `vex init` but nothing reads it — the only recipe that exists (`abstract`) is registered directly in `core/taskdefinitions.lua`. Auto-register a recipe per file, following the `{ add = function(task, taskproperties) ... end }` shape `Recipe:recipe` already expects.
