---
vexid: double-check-cascading-resolving-1
vextype: atom
description: Double check cascading and resolving through cascading tasks is bulletproof
created: "2026-10-19 07:55:01"
modified: "2026-10-30 03:20:22"
status: todo
---
Audit of when tasks are written and resolved (`src/core/task.lua`, `src/core/vexdex.lua`, `src/core/verbs.lua`). Every **confirmed** finding has a failing test in `test/e2e/resolution_spec.lua` tagged `(double-check-cascading-resolving-1)`; nothing has been fixed yet, so each fix below is a decision for discussion. Cascading itself (which tasks are reached, each once, moved to the right folder) held up in every case I tried.

## Confirmed loopholes

1. **A task file vex cannot parse vanishes silently (data loss, skipped validation).** `readfrompath` runs `taskformat.read` in a `pcall` and returns nil, so `resolve all` skips a truncated or frontmatter-less file with exit 0 and no warning. A truncated task file drops out of the index and `vex focus all` count. Fix: `reindexall` collects the unreadable paths and fails with a named error (`unreadable-task`) naming each file, before touching the index.
2. **Two files with one vexid are accepted.** `resolve all` reads both, keeps whichever it reads last, and leaves the other file on disk, invisible to every focus. Fix: `reindexall` fails with a named error (`duplicate-vexid`) listing both paths.
3. **Reading indexes unvalidated data.** `getsingle` reads a task from disk on first use in each process and `readfrompath` writes it straight into the index (`TaskManager:index`, which also rewrites all six index files each time). So `vex get`, `show` or `view` on a hand-edited file puts the unresolved edit into the index, with backlinks and derived fields not updated. `vex get all` also writes the index once per task. Fix: reading must never index. Only `resolve`, `write` and `reindexall` touch the index.
4. **`set` over a focus is not all-or-nothing.** `vex set a,b --cost 7` where `b` fails validation exits 1 but `a` has already been set and written. Fix: resolve and validate every task in the focus first, then write them (or stage all changes and commit together).
5. **A failed cascade leaves the index ahead of the files.** `set` on a task whose linked neighbour then fails validation exits 1 and leaves the file unchanged, but `resolvesingle` has already put the new version in the index and saved it. The index and the file now disagree until the next `resolve all`. Fix: stage index changes in memory during a cascade and only save the index once the whole cascade (and the writes) succeeded.

## Not tested, or needs your decision

6. **Write order.** Cascaded neighbours are written before the requested task. A crash between them leaves neighbours derived from a state that is not on disk. Fix: write the requested task first, or journal the cascade. Hard to test without killing the process; reasoning only.
7. **`delete` removes the file before re-resolving its neighbours.** A crash in between leaves dangling links that make every later `resolve all` fail on the first one. Fix: re-resolve the neighbours (staged) before the file removal, or have `resolve all` report dangling links by name.
8. **`resolve` and `resolve all` never write the requested tasks.** This is documented and `storage_spec` relies on it (a hand-written `due: tomorrow 8am` is kept until the next `set`), but it means the index holds normalised values the file does not. Decision: keep (file is the user's), or make `resolve` rewrite normalised files.
9. **A failed `resolve all` leaves invalid tasks in the index.** Reading indexes every file first (finding 3), so a task failing validation stays in the index as the unvalidated copy. Decision: should an invalid task be in the index at all?
10. **Concurrent processes.** The atomic-write temp name is `os.time()` plus `math.random(1000)`, and LuaJIT's `math.random` is unseeded: it gave `795` in three separate runs. Two vex processes started in the same second share a temp file and can overwrite each other. There is also no lock, so two simultaneous `set` calls can lose an index update, and no `fsync` before the rename. Fix: seed with the pid/clock, or use an exclusive-create temp name; add a lock file for write verbs.
11. **`previous` can be the disk copy.** `set` reads the task from disk before `resolvesingle` takes `previous` from the index, so after a hand edit the status-machine check and dropped-link detection compare against the hand-edited version, not the last resolved one. I could not make this observable through a link in a quick test, so it is unconfirmed.
12. **Every resolve bumps `modified` (`derive`)**, so one `set` rewrites the `modified` of every connected task: setting one atom touched 46 backlog files here. Overlaps [[check-modified-date-used-vex-1]].

Suggested order if you agree: 1, 2 (cheap, loud errors), then 3 and 5 together (one change: the index is only saved at the end of a successful command), then 4, then 10.