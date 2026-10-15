---
vexid: fix-vex-suggest-crashing-1
vextype: task
description: Fix vex suggest crashing
created: "2026-10-15 13:00:29"
modified: "2026-10-15 13:00:29"
status: todo
---
Found by the e2e smoke test and luacheck. `suggest.suggest` (`src/plugin/vexcomplete.lua`) writes debug output to a hardcoded `/home/tyronc/Nextcloud/projects/vex/.vex/current.txt`, so `vex suggest ...` crashes on any other machine. `suggest.recipe` also reads an undefined global `recipe` (`core.recipe` is never required). Shell completion is broken until both are fixed.