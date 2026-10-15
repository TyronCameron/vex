---
vexid: fix-throw-unregistered-error-1
vextype: task
description: Fix throw with unregistered error crashing
created: "2026-10-15 13:00:29"
modified: "2026-10-15 13:00:29"
status: todo
---
`CLI:throw` (`src/lib/cli.lua`) reads `self.errors[errtype][1]` before checking whether `errtype` is registered, so throwing an unknown error name crashes with "attempt to index a nil value" instead of reaching its own "Unknown error type" fallback.