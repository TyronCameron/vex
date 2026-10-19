---
vexid: make-csv-view-write-dataformat-1
vextype: atom
description: Make the csv view write through the dataformat plugin
created: "2026-10-19 09:21:53"
modified: "2026-10-19 09:21:53"
status: todo
---

[[Plugin architecture]] lists a `dataformat` slot (`default.csvdata`) that controls the format the `csv` view writes. `src/default/csvdata.lua` is an empty `return {}` stub and the `csv` view calls `lib.format.csv` directly, so the slot does nothing. Move the CSV writing behind the slot (`plugin:get 'dataformat'`) and give `default.csvdata` the implementation, or drop the slot and fix the docs.
