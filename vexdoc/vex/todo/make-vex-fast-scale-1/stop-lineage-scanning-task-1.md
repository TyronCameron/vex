---
vexid: stop-lineage-scanning-task-1
vextype: atom
description: Stop lineage scanning every task
created: "2026-10-31 05:55:58"
modified: "2026-10-31 05:56:04"
status: todo
---
The lineage and parent transients (src/core/taskdefinitions.lua) use Focus:reversetree, whose get_parents scans every task for a matching child, and byvexid() in src/core/focus.lua rebuilds a vexid table from Focus.getalltasks() on every call (also hit by acyclic and childless for each dependency). TaskManager:move computes lineage for every resolved task when paths.groupby uses it, so each resolve is O(n). Looking parents up through vexdex backlinks and using vexdex.index for byvexid cut a hub set at 1.45k tasks by about 35% in a local experiment. Verify: e2e lineage and grouping specs still pass; just bench.