---
vexid: load-config-files-hierarchically-1
vextype: atom
description: Load config files hierarchically
created: "2026-10-15 13:00:30"
modified: "2026-10-30 07:09:14"
status: todo
---
`Config:loadall` (`src/lib/config.lua`) supports several paths, later ones overriding earlier ones, but `src/core/config.lua` only registers `.vex/config.lua`. The design goal is an inheritance chain (e.g. user-level config, then each `.vex` from the outermost to the innermost), none of which is wired up.

The user-level step is done ([[load-config-extensions-plugins-1]]); the outermost-to-innermost chain of `.vex` folders is not.
