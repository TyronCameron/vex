How a task goes from `vex add` to a file on disk, and what else moves when it does. The code is `TaskManager` in `src/core/task.lua`.

## add, resolve, write

1. **`TaskManager:add`** makes a vexid with the `tagger` plugin and holds the new task in memory only.
2. **`TaskManager:resolve`** runs the schema of the task's type and of each type it extends, from the root down. Each schema runs three steps: normalise (fill defaults, convert values), validate, and derive (compute fields, record links). A failure throws a named `resolution-failed-*` error and nothing is written. Resolution then fingerprints the task (below), indexes it in memory, writes it and moves files into place.
3. **`TaskManager:write`** formats the task back to its readable form (a timestamp becomes `YYYY-MM-DD HH:MM:SS`, a vexid becomes `[[vexid]]`) and renders it through the `taskformat` plugin. If that is exactly what the file already holds, nothing is written. Otherwise it is written to a temporary file and renamed into place ([[The index]]).

Every resolve writes what it resolved, so a value you typed by hand (`due: tomorrow`) becomes a date as soon as the task is resolved. A task whose file would not change is never rewritten, so resolving again leaves every file, and git, alone.

## Fingerprints and `modified`

Whenever the vexdex indexes a task, it keeps a fingerprint of it (`VexDex:fingerprint`): a hash of every field and the body, leaving out the fields listed in `fingerprint.exclude` in `config.lua` (`modified` by default). At the end of resolving, if the resolved task's fingerprint differs from the one kept (`VexDex:changed`), the task's content changed, by a `set`, a hand edit, a value normalised or a field derived from a neighbour, and `modified` is set to now. Otherwise `modified` keeps its value, so a `set` that changes nothing, a resolve of an unchanged task and a rebuilt index never move it.

## Changes on disk

The vexdex also keeps the modification time vex last saw for each task file, and lists every file under `taskfolder` with its time in one go (`VexDex:updated`). An indexed task whose file's time differs is `updated`: edited by hand, pulled, checked out, moved, unreadable or gone. Before `show`, `get`, `set`, `view`, `remove` and `resolve` read their focus, vex resolves the tasks in it that are `updated`, so a hand edit is picked up the next time you look at the task. A file that was only touched resolves to the same fingerprint and is left as it is. Resolving a task whose file is gone or no longer readable drops it from the index, leaving any file alone, and resolves the tasks it was linked to.

`vex resolve all` (`TaskManager:reindexall`) resolves every `updated` task and reads in the files the vexdex doesn't know: new task files, and files moved by hand. `vex resolve all --force` first clears the index, so every file is read and resolved: use it when something other than a task file changed what resolution gives, such as `paths.groupby` or a task type.

The index is saved once, when the command finishes successfully ([[The index]]). A failure at any point, including a task further along a cascade, leaves the saved index as it was.

## Links

While deriving, every link a task holds is recorded, and the index stores them as backlinks. They answer both directions: `forwardlinks` and `backlinks` ([[08 Links and backlinks]]).

## Cascading

Resolving a task also resolves every task linked to it or from it, and every task it stopped linking to, transitively. Each task is resolved once per command, so cycles end, and derived fields stay right when a neighbour changes. The tasks reached this way are written back only if their files change, and their `modified` moves only if their content does.

## Arranging files

A task's file belongs where the `taskpath` plugin puts it, which with `paths.groupby` depends on its fields and its ancestors. After the cascade, `TaskManager:move` puts each resolved task's file there. So a parent's change moves its children, and a finished dependency moves its dependents. A move that is already in place does nothing, and emptied folders are removed.

## Removing

`TaskManager:remove` strips the removed vexid from every linking task, then resolves and writes those tasks, so validation stays strict and nothing dangles. `TaskManager:delete` then removes the file, drops the task from the index and resolves the tasks it linked to.
