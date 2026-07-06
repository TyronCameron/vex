---
vexid: fix-lux-entry-point-1
vextype: task
description: Fix lux.toml entry point mismatch
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`lux.toml`'s `[run] args = ["src/main.lua"]` points at a file that doesn't exist. The real entry point is `src/vex.lua` (invoked through the `src/vex` wrapper). Update `lux.toml` so `lux run` works, or document why it deliberately doesn't yet.
