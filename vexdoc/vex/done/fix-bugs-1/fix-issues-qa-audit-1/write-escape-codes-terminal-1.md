---
vexid: write-escape-codes-terminal-1
vextype: atom
description: Write escape codes only to a terminal
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
Colours and OSC-8 links were written even to pipes and files. `lib.pretty` now checks `isatty(1)` through the LuaJIT ffi and `NO_COLOR`. Resolution errors print the task file's path as text.