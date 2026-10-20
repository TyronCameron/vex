---
vexid: show-column-blank-missing-values-1
vextype: atom
description: Show every column and blank missing values in the tabular view
created: "2026-10-19 09:21:47"
modified: "2026-10-19 09:22:56"
status: done
---

`pretty.tabular` took its columns from the first row only, so a field the first task lacked (e.g. `children` when the first task is an atom) was dropped for every task, and a field a later task lacked printed as `nil`. Columns are now the union of every row's fields, and a missing value is a blank cell.
