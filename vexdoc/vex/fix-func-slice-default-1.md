---
vexid: fix-func-slice-default-1
vextype: task
description: Fix func slice default end
created: "2026-10-14 22:19:34"
modified: "2026-10-15 09:32:16"
status: done
---
`func.slice(tab, n)` (`src/lib/func.lua`) is meant to default `end_idx` to `start_idx` (and `start_idx` to 1). But it compares `end_idx < start_idx` before that, so a nil `end_idx` raises "attempt to compare nil with number". The `"end"`/`"begin"` string forms also hit numeric comparisons. Move the defaulting first and add tests.