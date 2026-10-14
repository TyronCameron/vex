---
vexid: create-linking-including-fixing-1
vextype: task
description: "Create linking, including fixing children and parent fields"
created: "2026-07-10 22:05:54"
modified: "2026-10-13 08:49:05"
status: done
---

Fixed. `children` on an abstract stays the single source of truth for parent links; there is no stored `parent` field.

- `--tree`/`--reversetree` (`core/focus.lua`) look tasks up by vexid, tolerate missing fields, and run `optic.traverse` from each focused task.
- `children` entries fail with `multiple-parents` when a task is already another abstract's child, and `dependencies` entries fail with `dependency-cycle` on a cycle (`core/errors.lua`).
- `schema.lua`'s `apply`/`unapply` run isos through container schemas, so `TaskManager:format` is `schema:apply('format', ...)`, and `children` and `dependencies` are written as `[[links]]`. `all` runs every subschema's prevalidate/postvalidate, and postvalidate now reaches through wrapper schemas.
- `vexlink` records each link during resolve, and the vexdex keeps them as backlinks (`vexdex/backlinks.bin`), exposed as `Focus:backlinks()`. `TaskManager:remove` uses them to strip the removed vexid from every property of each linking task, then resolves and rewrites those tasks.
- The `singular` view lists the parent chain, children, what the task depends on and what depends on it. The overview's "nil parent" stat uses `reversetree('children')`.

Covered by unit tests in `test/unit/core/{focus,task,taskdefinitions,vexdex}_spec.lua` and `test/unit/lib/schema_spec.lua`, plus `test/e2e/linking_spec.lua`.
