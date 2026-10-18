---
vexid: fix-set-dropping-unreadable-due-1
vextype: task
description: Fix set silently dropping an unreadable due
created: "2026-10-18 04:29:24"
modified: "2026-10-18 04:29:33"
status: done
---
`vex set x --due "garbage words"` exited 0 and removed `due` from the file: the datetime format iso returned nil for a value it could not read, and `maybe` accepted nil. The format iso now keeps the value, `formatted` falls back to the `interpret` iso, and a value neither can read fails resolution with `uninterpretable` before anything is written.