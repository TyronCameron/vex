---
vexid: keep-modified-forcing-resolve-1
vextype: atom
description: Keep modified on forcing a resolve of a freshly added task
created: "2026-11-05 22:20:47"
modified: "2026-11-05 22:20:53"
status: todo
---
`vex add` fingerprints the task as it is in memory, without a `vexbody` when none was given (`TaskManager:resolvesingle` → `VexDex:unsafe_add`). Read back from its file, the same task has `vexbody = ""`, so the next `vex resolve <vexid> --force` finds a different fingerprint and moves `modified` to now, although nothing changed. `vex resolve all --force` hides it because it reindexes every file before resolving. [[Resolution pipeline#Fingerprints and `modified`]] promises `modified` moves only on a real change. Reproduce: `vex add Steady task`, wait a second, `vex resolve steady-task-1 --force`, compare `modified`. Fix by making an empty body and no body the same value, then add a storage_spec test.