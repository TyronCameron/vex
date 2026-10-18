`.vex/config.lua` returns a Lua table and is read on every command. `vex init` writes this one:

```lua
return {
    taskfolder = '.',
    default = {
        tasktype = 'task'
    },
    taskowners = {}
}
```

## Settings

| Setting | Effect |
| --- | --- |
| `taskfolder` | The folder, relative to the project root, that holds the task files. |
| `taskowners` | The names `owner` may take. With no task owners, tasks can't have an owner. |
| `default.tasktype` | The `vextype` of a task added without one. |
| `paths.groupby` | Nests task files in folders by their fields (see below). |

For example, to keep tasks in a `todo` folder and assign them to two people:

```lua
return {
    taskfolder = 'todo',
    taskowners = {'alice', 'bob'},
}
```

## Grouping task files into folders

`paths.groupby` is a list of fields, transients included. Each one adds a level of folders, in order:

```lua
return {
    taskfolder = 'todo',
    paths = {
        groupby = {'lineage', 'status'},
    },
}
```

With this config, a task sits under its ancestors and then in a folder named after its status: `todo/version-01-1/doing/implement-config-defaults-1.md`.

- A list value such as `lineage` adds one folder per element. Unset values and empty lists add none.
- Characters that can't appear in a folder name (`/ \ : * ? " < > |`) become `-`.
- Files move whenever something they depend on changes. Changing a task moves the files of the tasks it links to, so editing a parent's `children` moves its children. Empty folders are removed.
- vex owns the layout. A file moved by hand is still found, and is moved back the next time it is resolved.
- After changing `paths.groupby`, run `vex resolve all` to move the existing files. Without it, task files sit flat at `<vexid>.md`.

## Layered config

vex reads every config on the way down to the project: your user config (`~/.vex/config.lua`), then the `config.lua` of each enclosing `.vex` folder, outermost first. Later files override earlier ones key by key. Shared settings such as `taskowners` can live in a parent folder and be refined per project.

This repository's own config sets `taskfolder = "vexdoc/vex"`: its backlog is the `vex` folder of this wiki.
