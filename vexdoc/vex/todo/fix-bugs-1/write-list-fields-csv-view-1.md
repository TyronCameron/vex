---
vexid: write-list-fields-csv-view-1
vextype: atom
description: Write list fields readably in the csv view
created: "2026-10-19 09:21:47"
modified: "2026-10-19 09:21:47"
status: todo
---

The `csv` view writes list fields (`children`, `options`, `dependencies`) as `table: 0x...`. [[04 Views]] promises the same data as the tabular view, quoted where needed, for spreadsheets, `duckdb` or scripts.

Decide on a list encoding that round-trips through a CSV reader (e.g. one quoted cell of comma-separated vexids), write it in `lib.format.csv`, and cover it in `test/unit/lib/format_spec.lua` and the e2e smoke view row.
