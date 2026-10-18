---
vexid: stop-optic-set-swallowing-1
vextype: task
description: Stop optic set swallowing
created: "2026-10-14 22:19:34"
modified: "2026-10-17 22:15:23"
status: done
---
Same issue as [[stop-optic-get-swallowing-1]], in `Optic:set` (`src/lib/optic.lua`): it ignores the `ok` from `coroutine.resume` and returns the error message as if it were the result. It should re-raise with `error(result, 0)`. Needs a test in `test/unit/lib/optic_spec.lua`.

No longer relevant: `lib.optic` was retired in [[retire-lib-optic-vex-1]].