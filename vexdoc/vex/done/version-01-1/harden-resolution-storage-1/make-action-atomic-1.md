---
vexid: make-action-atomic-1
vextype: atom
description: Consider making every action atomic
created: "2026-10-30 04:17:57"
modified: "2026-11-04 10:53:06"
status: done
---
**Undecided.** This is a place to weigh the idea, not a commitment, and nothing tests it. Decide first whether vex should guarantee that a command either writes everything or nothing.

Today only the index is all-or-nothing: it is saved once, when a command finishes successfully. Files are not: a command can fail or stop after it has already written some of them.

Found by the audit in [[double-check-cascading-resolving-1]]:

- **A focus-wide `set` or `remove` commits task by task.** `vex set a,b --cost 7` where `b` fails validation exits 1 but has already set and written `a`. Validating every task in the focus before writing any would avoid it.
- **Write order.** `resolveall` writes the cascaded neighbours before the verb writes the task it was asked to change. A crash between the two leaves neighbours derived from a state that is not on disk. Writing the requested task first, or staging every write and committing them together, would avoid it.
- **`delete` removes the file before re-resolving its neighbours.** A crash in between leaves dangling links, and `vex resolve all` then fails on the first one. Re-resolving the neighbours before removing the file would avoid it.
- **`remove` strips links, then `delete` removes the file** as two separate steps with the same exposure.

If it is decided, add one failing e2e test per case before building it.

**Decided and done.** `TaskManager:resolveall` now resolves in memory only and keeps what it resolved; `TaskManager:delete` queues the file's removal. Each verb calls `TaskManager:writeall` once, after all its resolving, so a verb that fails on a later task writes no file. A write failing partway is not rolled back. The e2e test "writes no task file when a verb fails on a later task" covers the focus-wide `set` case.
