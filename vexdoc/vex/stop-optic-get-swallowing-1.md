---
vexid: stop-optic-get-swallowing-1
vextype: task
description: Stop optic get swallowing errors
created: "2026-10-13 22:14:55"
modified: "2026-10-13 22:14:55"
status: todo
---

`Optic:get` (`src/lib/optic.lua`) resumes its coroutine and stops collecting results as soon as `coroutine.resume` returns `ok == false`, so any error inside an optic (a nil index, a bad children function) is silently swallowed and the caller gets a partial result. This hid the original `--tree`/`--reversetree` bugs for a long time: they quietly returned the input list instead of crashing.

`Optic:get` should re-raise the coroutine's error (e.g. `if not ok then error(val, 0) end`) rather than treating it as the end of the iteration. Needs a test in `test/unit/lib/optic_spec.lua` showing an erroring optic propagates its error.
