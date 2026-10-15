---
vexid: fix-func-last-off-1
vextype: task
description: Fix func last off by one
created: "2026-10-14 22:19:34"
modified: "2026-10-15 09:31:53"
status: done
---
`func.last(tab, n)` (`src/lib/func.lua`) slices from `#tab - n`, returning `n + 1` elements (e.g. `func.last({1,2,3})` gives `{2,3}`). It should start at `#tab - n + 1`. Needs a test in `func_spec.lua`.