---
vexid: make-tabular-view-show-selected-1
vextype: atom
description: Make the tabular view show only selected fields
created: "2026-10-19 09:21:47"
modified: "2026-10-30 01:33:49"
status: done
---

The tabular view merged each task's full formatted copy into the row, so `vex focus all --select status` still showed every field. [[04 Views]] promises that a focus built with `--select` shows only the selected fields. The view now takes only the focused task's own fields, formatted.
