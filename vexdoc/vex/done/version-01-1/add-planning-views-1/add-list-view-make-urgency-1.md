---
vexid: add-list-view-make-urgency-1
vextype: atom
description: Add a list view and make urgency dependency-aware
created: "2026-11-02 22:20:18"
modified: "2026-11-02 22:21:17"
status: done
---
Added the `list` view (src/core/view.lua, [[04 Views]]), ordered the `ready` focus by the new `deadline` transient, and made `urgency` rank by `deadline`, `prerequisites`, `due` so dependencies come first (src/core/taskdefinitions.lua, [[02 Frontmatter schema]]). Verify: just test.