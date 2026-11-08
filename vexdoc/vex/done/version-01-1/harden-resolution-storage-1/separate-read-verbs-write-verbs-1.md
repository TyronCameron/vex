---
vexid: separate-read-verbs-write-verbs-1
vextype: atom
description: Separate read verbs from write verbs
created: "2026-11-06 11:58:29"
modified: "2026-11-06 11:58:42"
status: done
---
Read verbs wrote: `focus_pop_args` in `src/core/verbs.lua` resolved and wrote back the hand-edited tasks in the focus before `show`, `get` and `view`; the `post-verb-*` hook in `src/core/vexdex.lua` saved the index whenever it was dirty; `VexDex:ensureindex` wrote an empty index; and `Task.__index` and `TaskManager:format` read task files for the body. Now read verbs (`show`, `get`, `view`, `focus`) only read: `get`, `view` and `focus` read the committed index and warn on stderr (`cli:warn`) while the `updated` focus is not empty, and `show` prints the task file as it is on disk through the `taskformat` plugin's `show`, the only way to see `vexbody`. Write verbs take in hand edits with `focus_take_in` and commit once: `TaskManager:writeall` saves the index, the only place it is saved. The overview view's body stat is gone. [[01 CLI reference]] marks what each verb reads and writes, and `test/e2e/storage_spec.lua` checks every row.