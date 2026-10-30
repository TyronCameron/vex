---
vexid: make-action-atomic-1
vextype: atom
description: Make every action atomic
created: "2026-10-30 04:17:57"
modified: "2026-10-30 04:18:18"
status: todo
---
Today only the index is all-or-nothing (it is saved once, when a command finishes successfully). Files are not: a command can fail or stop after it has already written some of them. Make each action all-or-nothing, so nothing is written unless everything validates.

Found by the audit in [[double-check-cascading-resolving-1]]:

- **A focus-wide `set` or `remove` commits task by task.** `vex set a,b --cost 7` where `b` fails validation exits 1 but has already set and written `a`. Resolve and validate every task in the focus first, then write them. The test is `test/e2e/resolution_spec.lua` ("does not commit the tasks before a failing one when setting a focus"), and it fails until this is fixed.
- **Write order.** `resolveall` writes the cascaded neighbours before the verb writes the task it was asked to change. A crash between the two leaves neighbours derived from a state that is not on disk. Write the requested task first, or stage every write and commit them together.
- **`delete` removes the file before re-resolving its neighbours.** A crash in between leaves dangling links, and `vex resolve all` then fails on the first one. Re-resolve the neighbours (staged) before removing the file.
- **`remove` strips links, then `delete` removes the file** as two separate steps with the same exposure.

Verify: one failing-then-passing e2e test per case, and `just test`.