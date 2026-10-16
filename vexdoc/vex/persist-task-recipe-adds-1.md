---
vexid: persist-task-recipe-adds-1
vextype: task
description: Persist every task a recipe adds
created: "2026-10-15 13:00:30"
modified: "2026-10-15 13:00:30"
status: todo
---
`Recipe:add` (`src/core/recipe.lua`) only resolves and writes the single vexid the recipe's `add` function returns, so a recipe that calls `task:add` several times only persists the last task (see the recipe example in `vexdoc/Home.md`). Every task a recipe adds should be resolved and written.