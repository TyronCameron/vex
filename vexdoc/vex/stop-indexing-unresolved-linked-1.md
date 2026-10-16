---
vexid: stop-indexing-unresolved-linked-1
vextype: task
description: Stop indexing unresolved linked tasks
created: "2026-10-15 13:09:11"
modified: "2026-10-16 10:49:56"
status: done
---
Found by the new e2e smoke test. After `vex resolve all` on linked tasks, `vex set <a task with dependencies> --status doing` leaves the *linked* task in the vexdex with its frontmatter as written on disk: `created`/`modified` as "YYYY-MM-DD HH:MM:SS" strings instead of epoch numbers. `TaskManager:readfrompath` (`src/core/task.lua`) indexes whatever `taskformat.read` returns without resolving (unformatting) it, and resolving a task reads its links through `getsingle`. Once the index holds strings, `vex view all overview` (`view.lua:183`), `vex view <id> singular` (`view.lua:221`) and `vex focus updated` (`focus.lua:42`) all crash comparing strings with numbers. Reproduced by the `test/e2e/smoke_spec.lua` fixture.

Even read-only verbs trigger it: `vex view all tabular` calls `task:format` on every task, which reads each one from disk through `getsingle` and writes the raw data back to the index. After that, `vex view all overview` crashes on this repo's own backlog (`test/e2e/dogfood_spec.lua`).

Fixed by unformatting on read rather than skipping the index: `TaskManager:readfrompath` runs the task through `TaskManager:unformat` (the schema's `unapply('format')`, mirroring `TaskManager:format`) before storing and indexing it, so reads keep the index up to date with hand edits and the index only ever holds unformatted values.