---
vexid: fail-atomic-write-cannot-rename-1
vextype: task
description: Fail loudly when an atomic write cannot rename
created: "2026-10-16 23:11:58"
modified: "2026-10-16 23:11:59"
status: todo
---
VexDex:atomic (src/core/vexdex.lua) ignores os.rename's result. If the target folder is missing (e.g. .vex/vexdex/ in a fresh clone, since git does not track empty folders), every write is silently dropped: vex resolve all exits 0, writes no index, and leaves its temp files behind in .vex/tmp. It should throw a named CLI error (e.g. the existing write error) when the rename fails, and the e2e storage spec should cover a missing vexdex folder.