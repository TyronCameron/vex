---
vexid: fix-csv-view-dropping-fields-1
vextype: task
description: Fix csv view dropping fields missing from the first task
created: "2026-10-17 22:40:04"
modified: "2026-10-17 22:40:44"
status: done
---
`format.csv` (`src/lib/format.lua`) took its columns from the first record only, in `pairs` order. A field missing from the first task, such as a transient that is nil for it, disappeared from every row, and the column order changed between runs. It now writes a column for every field of any record, sorted by name, and leaves missing values empty instead of writing `nil`.