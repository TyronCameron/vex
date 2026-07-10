---
vexid: fix-init-requires-existing-vex-1
vextype: task
description: Fix vex init crashing outside an existing .vex tree
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

Confirmed by actually running `./src/vex init` in a fresh directory with no `.vex` anywhere above it (while writing the Installing vex wiki page): every command, including `init` itself, crashes with "Not in a vex directory." Root cause: `src/vex.lua`'s `plugin:each(function(plug) end)` eagerly loads every registered plugin, including `src/plugin/vexcomplete.lua`, which `require`s `core.focus` → `core.vexdex`. `core/vexdex.lua`'s last line is `return VexDex.new()`, executed at module-load time, and `VexDex.new()` throws `not-vexed` immediately if no `.vex` folder is found walking up from the cwd. This happens *before* `cli:run` even dispatches to the `init` verb's own body, so `init` never gets a chance to create the folder that would fix the problem.

This only goes unnoticed because this repo's own `.vex` folder (used to dogfood vex's own backlog) is always an ancestor of wherever the developer runs vex from. A genuinely fresh clone, or any new project elsewhere, can't bootstrap at all today. No user-side workaround exists — pre-creating `.vex` manually just trips `init`'s own "already-vexed" guard instead, which uses the identical ancestor-search check.

Fix direction: make `VexDex` construction lazy (don't run `VexDex.new()` at `require` time), or have the eager plugin loader tolerate/skip a plugin failing to load for this specific reason during `init`.
