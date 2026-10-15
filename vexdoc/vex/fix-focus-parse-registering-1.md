---
vexid: fix-focus-parse-registering-1
vextype: task
description: Fix Focus parse registering no-focus
created: "2026-10-15 13:00:29"
modified: "2026-10-15 13:00:29"
status: todo
---
`Focus.parse` (`src/core/focus.lua`) calls `cli:error('no-focus')`, which registers a new (empty) `no-focus` error type, instead of `cli:throw('no-focus')`. When there is no current focus it carries on with a nil focus.