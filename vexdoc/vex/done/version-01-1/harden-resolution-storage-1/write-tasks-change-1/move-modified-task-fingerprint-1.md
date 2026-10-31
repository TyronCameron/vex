---
vexid: move-modified-task-fingerprint-1
vextype: atom
description: Move modified only when a task fingerprint changes
created: "2026-10-31 04:50:57"
modified: "2026-10-31 22:02:19"
status: done
---
`modified` was a `schema.derive` reset on every resolve (`src/core/taskdefinitions.lua`), and `TaskManager:set` set it again, so every resolve, every no-op `set` and every cascade put a new `modified` into git. Now `modified` is a `schema.default`. The vexdex keeps a fingerprint of every task it indexes (`VexDex:fingerprint`, an FNV-1a hash from `src/lib/hash.lua` of the fields and body without those in `config.fingerprint.exclude`), and `TaskManager:resolvesingle` sets `modified` to now only when `VexDex:changed` says the resolved task differs. See [[Resolution pipeline]]. Verified by `test/e2e/storage_spec.lua` (backdated tasks keep `modified` through resolves and no-op sets) and `test/unit/core/vexdex_spec.lua`.