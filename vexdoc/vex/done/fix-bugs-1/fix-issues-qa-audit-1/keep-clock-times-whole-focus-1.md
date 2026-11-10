---
vexid: keep-clock-times-whole-focus-1
vextype: atom
description: Keep clock times whole in focus flag values
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
`Focus:apply` split every flag value on `:`, so `--filter 'due:2026-11-09 08:00:00'` could not work. It now splits only at colons outside a clock time written after a date or word. See [[01 CLI reference]].