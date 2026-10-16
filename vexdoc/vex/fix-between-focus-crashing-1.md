---
vexid: fix-between-focus-crashing-1
vextype: task
description: Fix between focus crashing on CLI values
created: "2026-10-15 13:00:29"
modified: "2026-10-16 02:05:14"
status: done
---
Found by the e2e smoke test. `vex focus all --between created:0:9999999999` crashes with an Internal error: `Focus:between` (`src/core/focus.lua`) compares the raw CLI strings `start`/`finish` with the task's field (`attempt to compare string with number`). The bounds need converting through the field's schema (e.g. `due` as a datetime, `cost` as a number) before comparing.

Fixed for numeric bounds. Datetime bounds need a design decision first, tracked in [[decide-how-between-takes-1]].