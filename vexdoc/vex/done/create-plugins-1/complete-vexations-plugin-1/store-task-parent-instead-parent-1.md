---
vexid: store-task-parent-instead-parent-1
vextype: atom
description: "Store each task's parent instead of each parent's children"
created: "2026-11-09 21:13:50"
modified: "2026-11-09 21:13:54"
parent: "[[complete-vexations-plugin-1]]"
status: done
---
Abstracts stored `children` and decisions stored `options`, so adding a child meant editing the parent, `singleparent` scanned every task linking to the child, nothing stopped a cycle longer than one step, and an abstract's phase scanned every task.

Each task now stores one `parent` link (`schema.parent` in `src/core/schemaext.lua`, on `basetask`), checked by `acyclic {'parent', 'parent-cycle'}` and by `adoptive`, which asks the target's `acceptschildren` transient (true on `basetask`, false for atoms and explorations in `src/plugin/vexations.lua`). `children` is a transient of the backlinks whose `parent` is the task, and a decision's `decision` must be one of its children. `multiple-parents` and `self-child` are gone, `parent-cycle` and `childless-parent` are new. `scripts/migrate-parents.lua` moved this backlog over, and is described in [[03 Task types (and vexations)]].

Verify: `just test`, including `test/e2e/migration_spec.lua` and `dogfood_spec.lua`.