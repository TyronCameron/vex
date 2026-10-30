The vexdex (`src/core/vexdex.lua`) is vex's index: a map from each vexid to its task data, kept in `.vex/vexdex` so that commands don't read every task file on every run. It is derived entirely from the task files, so keep it out of git and rebuild it with `vex resolve all`.

## On disk

| File | Holds |
| --- | --- |
| `index.bin` | Every task's fields, unformatted: timestamps as numbers, links as bare vexids. |
| `backlinks.bin` | For every task, the tasks that link to it. |
| `paths.bin` | Where each task file is, relative to `taskfolder`. |
| `focus.bin` | The saved focus, as the list of operations that rebuild it. |

Each `.bin` file is written with `binser` and is what vex reads. Next to it, a `.lua` file holds the same data in readable form. vex never reads the `.lua` files; they exist so you can inspect the index.

With `paths.groupby` set, a file's location depends on its fields and on other tasks, so vex records it in `paths.bin`. If a file isn't where it was recorded, because it was moved by hand or after a merge, vex finds it by its filename and moves it back.

## Atomic writes

Every write goes through `VexDex:atomic`. The data is written to a new file in `.vex/tmp` and then renamed into place, so an interrupted write never leaves a half-written file. If the rename fails, vex stops with the `write` error and leaves the data in `.vex/tmp`.

## When the index is saved

Commands change the index in memory as they go and save it once, when the command finishes successfully. A command that fails, because a task doesn't validate or a file can't be read, saves nothing, so the index on disk is never left half-updated. Reading a task never changes the index: only resolving, writing and `vex resolve all` do, so a file you edited by hand is not in the index until it is resolved.

## Loading and rebuilding

When a command starts, vex loads the index from `.vex/vexdex`. If the folder or the index doesn't exist yet, as in a fresh clone, vex creates it, starting empty.

`add`, `set`, `remove` and `resolve` update the index for the tasks they touch. To pick up changes made outside vex, such as files edited, added or deleted by hand, a script or an AI agent, run:

```console
$ vex resolve all
```

This clears the index, reads every task file under `taskfolder` and resolves each. It stops, changing nothing, if a file starts a frontmatter (`---`) but can't be read, or if two files hold the same vexid. Markdown files without frontmatter are ignored.

## See also

- [[01 Configuring vex (config.lua)]] for `taskfolder` and `paths.groupby`.
- [[Plugin architecture]] for the `taskformat`, `frontmatter` and `sortdata` plugins used to read and write task files.
