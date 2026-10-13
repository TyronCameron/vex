---
vexid: create-linking-including-fixing-1
vextype: task
description: "Create linking, including fixing children and parent fields"
created: "2026-07-10 22:05:54"
modified: "2026-10-13 08:49:05"
status: done
---

Fixed. `children` on an abstract stays the single source of truth for parent links; there is still no stored `parent` field.

- `--tree`/`--reversetree` (`core/focus.lua`) look tasks up by vexid, skip tasks that don't have the field, and collect each focused task plus everything reachable from it.
- `children` entries are checked so that a task appears in at most one abstract's `children` (`multiple-parents` error). `dependencies` entries are checked for cycles (`dependency-cycle` error). Both errors live in `core/errors.lua`. To support this, `schema.all` now runs each subschema's prevalidate.
- `TaskManager:format` now formats list elements, so both `children` and `dependencies` are written as `[[links]]`. Before this change `children` was being written back as bare ids too.
- `vex remove` strips the removed vexids from every other task's `children`/`dependencies` and rewrites the tasks it changed.
- The `singular` view lists the parent chain, children, what the task depends on and what depends on it. The overview's "nil parent" stat uses `reversetree('children')`.

Covered by unit tests in `test/unit/core/focus_spec.lua`, `test/unit/core/taskdefinitions_spec.lua` and `test/unit/lib/schema_spec.lua`, plus `test/e2e/linking_spec.lua`.
