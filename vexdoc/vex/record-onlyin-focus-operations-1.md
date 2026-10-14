---
vexid: record-onlyin-focus-operations-1
vextype: task
description: Record onlyin focus operations
created: "2026-10-14 22:19:33"
modified: "2026-10-14 22:19:33"
status: todo
---
`Focus:onlyin` (`src/core/focus.lua`) is the only set operation that passes no `operations` to `Focus.new`, so it falls back to `{focus, {"onlyin"}}`. Saving and replaying such a focus throws `unknown-focus onlyin`. It should record `{operation = "onlyin", ...}` like `notin` does.