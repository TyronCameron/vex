---
vexid: add-repeat-recipe-adds-task-n-1
vextype: atom
description: Add a repeat recipe that adds a task n times
created: "2026-11-07 11:27:12"
modified: "2026-11-07 11:27:25"
status: done
---
`vex recipe repeat Wash the dishes --n 100` adds the task 100 times (`src/core/recipe.lua`); under vexations the copies sit inside an abstract added first (`src/plugin/vexations.lua`). Documented in [[03 Using a recipe to create a sequence of tasks]], tested in `test/e2e/recurring_spec.lua`.