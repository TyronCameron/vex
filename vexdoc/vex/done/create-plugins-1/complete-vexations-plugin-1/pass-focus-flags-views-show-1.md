---
vexid: pass-focus-flags-views-show-1
vextype: atom
description: Pass tabular view flags to its focus and show groups
created: "2026-10-24 22:45:32"
modified: "2026-10-25 12:12:32"
status: done
---
`vex view` handed its flags to the view as a hash, and the `tabular` view ignored them, so ordering, grouping or filtering a table meant saving a new focus first. The view also flattened a grouped focus with `focus:get()`, so the groups vanished. [[04 Views]] and [[01 CLI reference]] describe both.

`vex view` now also passes views the flags in the order typed. The `tabular` view (`src/core/view.lua`) applies them all to its focus with `Focus:apply` (`src/core/focus.lua`) without writing it, so `prev` is untouched; any flag that isn't a focus operation throws `unknown-focus-operation`. A `FocusGroups` holds what it groups by (`by`) and works out its groups lazily, and the `tabular` view puts a `pretty.subheader` above each group, one level per field. `pretty.tabular` (`src/lib/pretty.lua`) indents each level 2 spaces with a dim guide line. Verify with `test/e2e/view_spec.lua`, the grouping specs in `test/unit/core/focus_spec.lua`, `view_spec.lua` and `pretty_spec.lua`, and `just test`.