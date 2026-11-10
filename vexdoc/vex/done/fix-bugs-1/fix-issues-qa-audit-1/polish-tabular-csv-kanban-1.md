---
vexid: polish-tabular-csv-kanban-1
vextype: atom
description: "Polish the tabular, csv, kanban and overview views"
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
An abstract's derived status was blank in tabular and csv, a selected column with no values vanished, a group with no value had an empty label, CJK text misaligned columns, an empty focus printed a blank line, and overview spoke of nil parents. All are fixed in `src/core/view.lua` and `pretty.tabular`.