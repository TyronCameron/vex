---
vexid: pass-focus-flags-views-show-1
vextype: atom
description: Pass focus flags through views and show groups in tabular
created: "2026-10-24 22:45:32"
modified: "2026-10-24 22:45:32"
status: done
---
`vex view` handed its flags to the view as a hash, and the `tabular` view ignored them, so ordering, grouping or filtering a view meant saving a new focus first. The view also flattened a grouped focus with `focus:get()`, so the groups vanished. [[04 Views]] and [[01 CLI reference]] describe both.

The `view` verb (`src/core/verbs.lua`) now runs every flag that `Focus.operates` names through `Focus.parse`, in order, without writing the focus; other flags (kanban's `--field`) still go to the view. A grouped focus names its `groupfields` (`src/core/focus.lua`), and the `tabular` view (`src/core/view.lua`) puts a `pretty.subheader` above each group, one level per field. `pretty.tabular` (`src/lib/pretty.lua`) indents each level 2 spaces with a dim guide line. Verify with `test/e2e/view_spec.lua`, the grouping specs in `test/unit/core/focus_spec.lua`, `view_spec.lua` and `pretty_spec.lua`, and `just test`.