---
vexid: load-project-plugins-vex-folder-1
vextype: atom
description: Load project plugins from the vex folder
created: "2026-10-19 09:21:53"
modified: "2026-11-04 02:09:32"
status: done
---

[[Plugin architecture]] says to replace a slot's implementation by adding a module of the same name under `src/plugin`. That means editing vex's own source: a project has no way to ship a plugin. `Plugin:addall` only scans `src/plugin`, and `load` only requires `plugin.<name>` from vex's `package.path`.

Add a `.vex/plugins/` folder (created by `vex init`), put it ahead of `src/plugin` on the search path, and register its files the way `src/plugin` is registered. Cover it with an e2e test that swaps the `tagger` for a project-local one. Depends on choosing the active member from config ([[implement-config-defaults-1]]) for new members to be selectable.

Done as `.vex/plugin/` (singular, like the global folder's `plugin/`), created by `vex init`, put ahead of `src/plugin` on the search path and registered with the rest. Select a project member with `plugins = { slot = 'name' }` ([[implement-config-defaults-1]]). Covered by `test/e2e/config_spec.lua`, which swaps the `tagger` for a project-local one.
