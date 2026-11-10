---
vexid: stop-vex-suggest-crashing-words-1
vextype: atom
description: Stop vex suggest crashing without words
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
`vex suggest` with no arguments crashed on `tonumber(nil)` in `src/plugin/vexcomplete.lua`. It now prints nothing. `vex autocomplete` without a shell names the shells, and each snippet is fenced as its own shell.