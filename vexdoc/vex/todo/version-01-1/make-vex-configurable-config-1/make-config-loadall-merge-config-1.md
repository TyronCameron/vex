---
vexid: make-config-loadall-merge-config-1
vextype: atom
description: Make Config loadall merge config files with func.merge
created: "2026-11-05 22:18:04"
modified: "2026-11-05 22:18:11"
status: todo
---
`Config:loadall` in `src/lib/config.lua` merges each config file's table into `self.properties` with its own `pairs` loop, later files overwriting earlier ones. That is `func.merge` (`src/lib/func.lua`), so it should use it. Behaviour stays the same: a project's top-level key replaces the global folder's. See [[01 Configuring vex (config.lua)]]. Verify with test/unit/lib/config_spec.lua and test/e2e/global_spec.lua.