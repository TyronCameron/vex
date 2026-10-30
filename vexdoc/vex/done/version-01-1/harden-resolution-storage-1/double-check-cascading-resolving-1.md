---
vexid: double-check-cascading-resolving-1
vextype: atom
description: Double check cascading and resolving through cascading tasks is bulletproof
created: "2026-10-19 07:55:01"
modified: "2026-10-30 04:18:18"
status: done
---
Audit of when tasks are written and resolved (`src/core/task.lua`, `src/core/vexdex.lua`, `src/core/verbs.lua`). Cascading itself (which tasks are reached, each once, moved to the right folder) held up in every case I tried. Findings, with their tests in `test/e2e/resolution_spec.lua` (tagged with this task):

## Fixed

1. **A task file vex could not parse vanished silently.** `resolve all` now stops with `unreadable-task`, naming the file, for a file that starts a frontmatter but can't be read. Markdown without frontmatter is still ignored.
2. **Two files with one vexid were accepted.** `resolve all` now stops with `duplicate-vexid`, naming both files.
3. **Reading indexed unvalidated data.** Reading a task no longer touches the index; only resolving, writing and `resolve all` do. As a result `previous` in resolution is always the last resolved version (a hand edit can no longer replace it before the state machine and dropped-link checks look at it).
5. **A failed cascade left the index ahead of the files.** The index is now changed in memory and saved once, when the command finishes successfully, so a failure anywhere saves nothing. A failed `resolve all` also no longer leaves a half-built index.
10. (part) `math.random` is now seeded with the time, so temp-file names differ between runs.

## Intentional, not a loophole

8. `resolve` validates, normalises, derives and moves files, and never writes the tasks it resolves. Documented in the Resolution pipeline page.

## Raised as tasks and for discussion

4, 6, 7. A focus-wide `set` commits task by task; cascaded neighbours are written before the requested task; `delete` removes the file before re-resolving its neighbours. All three are about files not being all-or-nothing: [[make-action-atomic-1]].

10. (rest) Two vex processes started in the same second still draw the same temp-file name, there is no lock between concurrent writers, and nothing calls `fsync` before the rename.

12. Every resolve bumps `modified` (it is a `derive`), so one `set` rewrites the `modified` of every connected task: setting one atom touched 46 backlog files here. Overlaps [[check-modified-date-used-vex-1]].