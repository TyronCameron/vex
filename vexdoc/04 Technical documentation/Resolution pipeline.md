How a task goes from `vex add` to a file on disk, and what else moves when it does. The code is `TaskManager` in `src/core/task.lua`.

## add, resolve, write

1. **`TaskManager:add`** makes a vexid with the `tagger` plugin and holds the new task in memory only.
2. **`TaskManager:resolve`** runs the schema of the task's type and of each type it extends, from the root down. Each schema runs three steps: normalise (fill defaults, convert values), validate, and derive (compute fields, record links). A failure throws a named `resolution-failed-*` error and nothing is written. Resolution then indexes the task in memory and moves files into place (below).
3. **`TaskManager:write`** formats the task back to its readable form (a timestamp becomes `YYYY-MM-DD HH:MM:SS`, a vexid becomes `[[vexid]]`), writes it through the `taskformat` plugin to a temporary file and renames it into place ([[The index]]).

`add`, `set` and `recipe` do all three. `vex resolve` only validates, normalises, derives and moves files: it never writes the tasks it was asked to resolve, so a value you typed by hand (`due: tomorrow`) stays as typed until vex next writes the task. `vex resolve all` first rebuilds the index from the files on disk (`TaskManager:reindexall`), then resolves each.

The index is saved once, when the command finishes successfully ([[The index]]). A failure at any point, including a task further along a cascade, leaves the saved index as it was.

## Links

While deriving, every link a task holds is recorded, and the index stores them as backlinks. They answer both directions: `forwardlinks` and `backlinks` ([[08 Links and backlinks]]).

## Cascading

Resolving a task also resolves every task linked to it or from it, and every task it stopped linking to, transitively. Each task is resolved once per command, so cycles end, and derived fields stay right when a neighbour changes. The tasks reached this way are written back. (A neighbour's `modified` changes with it.)

## Arranging files

A task's file belongs where the `taskpath` plugin puts it, which with `paths.groupby` depends on its fields and its ancestors. After the cascade, `TaskManager:move` puts each resolved task's file there. So a parent's change moves its children, and a finished dependency moves its dependents. A move that is already in place does nothing, and emptied folders are removed.

## Removing

`TaskManager:remove` strips the removed vexid from every linking task, then resolves and writes those tasks, so validation stays strict and nothing dangles. `TaskManager:delete` then removes the file and resolves the tasks it linked to.
