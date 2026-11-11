---
vexid: store-task-parent-instead-parent-1
vextype: atom
description: "Store each task's parent instead of each parent's children"
created: "2026-11-09 21:13:50"
modified: "2026-11-11 21:58:41"
parent: "[[complete-vexations-plugin-1]]"
status: done
---
Abstracts stored `children` and decisions stored `options`, so adding a child meant editing the parent, `singleparent` scanned every task linking to the child, nothing stopped a cycle longer than one step, and an abstract's phase scanned every task.

Each task now stores one `parent` link (`schema.parent` in `src/core/schemaext.lua`, on `basetask`), checked by `acyclic {'parent', 'parent-cycle'}`. `children` is a transient of the backlinks whose `parent` is the task, checked on the parent through `schema.unstored` (`src/lib/schema.lua`): `isvalidparent` on `basetask` (nothing depends on a task with children) and the vexations plugin's `hasnochildren` on atoms and explorations (`has-children`). A decision's `decision` must be one of its children. `multiple-parents` and `self-child` are gone, `parent-cycle` and `has-children` are new, and `reversetree` is retired in favour of `--tree parent`. `scripts/migrate-parents.lua` moved this backlog over, and is described in [[03 Task types (and vexations)]].

Verify: `just test`, including `test/e2e/migration_spec.lua` and `dogfood_spec.lua`.

Review follow-up: storing the link on the child meant a task gaining a child no longer re-resolved the tasks depending on it, so `childless` never saw the new child; the parent now checks it. `vex resolve all --force` also links each file as it reads it, so checks that read `children` don't depend on file order.
