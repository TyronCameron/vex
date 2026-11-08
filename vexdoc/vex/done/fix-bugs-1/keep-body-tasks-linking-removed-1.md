---
vexid: keep-body-tasks-linking-removed-1
vextype: atom
description: Keep the body of tasks linking to a removed task
created: "2026-11-07 11:20:28"
modified: "2026-11-07 11:24:16"
status: done
---
`TaskManager:remove` (`src/core/task.lua`) stripped the removed vexid from the tasks linking to it using their index copies, which hold no body, then resolved and wrote them, so removing a task wiped the body of every task linking to it. It now strips the link from each linking task as read from its file (`getsingle`). The index also no longer holds a body even in memory (`VexDex:unsafe_add` keeps a body-free copy), so a write verb can only ever write a task read from its file. Verified by `keeps the body of a task linking to a removed task` in `test/e2e/storage_spec.lua`.