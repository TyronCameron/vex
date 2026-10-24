---
vexid: make-tabular-view-put-subheaders-1
vextype: atom
description: Make tabular view put subheaders up for abstracts
created: "2026-10-19 07:28:00"
modified: "2026-10-19 09:22:05"
status: todo
---

When the tabular view shows abstracts and their descendants, group rows under a subheader per abstract (following `children`), instead of one flat table.

`vex view tabular --groupby lineage` (from [[pass-focus-flags-views-show-1]]) now gives a subheader per ancestor line; what is left is nesting by each abstract in `children` rather than by the whole lineage.
