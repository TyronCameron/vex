---
vexid: fix-typed-field-cli-input-1
vextype: task
description: Fix numeric and datetime fields failing validation from the CLI
created: "2026-07-06 12:00:00"
modified: "2026-07-11 22:00:00"
status: done
---

Fixed. Two independent bugs were stacked here:

1. `schema.num` (`src/lib/schema.lua`) had no `prevalidate` at all, so a CLI-supplied string like `"15"` was never coerced to a number before `validate` ran.
2. `schema.maybe`'s `prevalidate` delegated to the shared `prevalidate_children` helper, which only descends when `type(instance) == "table"`. That gate is correct for real table containers (`exactly`/`atmost`/`atleast`/`vec`) but wrong for `maybe`, whose own `iterate` always yields `instancekey = nil` (it wraps a single value, not table members) — so the wrapped schema's `prevalidate` (the `num` coercion above, and `formatted{datetime}`'s existing, already-correct string→epoch conversion) never even ran for `due`, `cost`, or `benefit`, all of which are `maybe`-wrapped.

`formatted`'s own `unapply('format', ...)` conversion was not itself buggy, as originally suspected — it was simply never reached.

Fix: added the `num` coercion, and rewrote `maybe`'s `prevalidate` to use an unconditional loop (matching the pattern `default`/`derive` already used) instead of the table-gated helper. `vex add Buy new mug --cost 15 --benefit 40 --due 2026-08-01T09:00:00` now resolves cleanly, as does hand-editing a `due`/`cost`/`benefit` value directly into a task file and running `vex resolve`. Covered by new unit tests in `test/unit/lib/schema_spec.lua` and e2e coverage in `test/e2e/lifecycle_spec.lua`.
