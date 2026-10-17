---
vexid: stop-optic-get-swallowing-1
vextype: task
description: Stop optic get swallowing errors
created: "2026-10-13 22:14:55"
modified: "2026-10-14 22:14:24"
status: done
---
Fixed. Optic:get re-raises the coroutine's error instead of returning a partial result. Optic:set has the same problem and is tracked separately.