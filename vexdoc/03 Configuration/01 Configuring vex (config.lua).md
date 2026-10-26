`.vex/config.lua` returns a Lua table and is read on every command. `vex init` writes this one:

```lua
return {
    taskfolder = '.',
    default = {
        tasktype = 'task'
    },
    taskowners = {},
    loglimit = 1000
}
```

## Settings

| Setting | Effect |
| --- | --- |
| `taskfolder` | The folder, relative to the project root, that holds the task files. |
| `taskowners` | The names `owner` may take. With no task owners, tasks can't have an owner. |
| `default.tasktype` | The `vextype` of a task added without one. |
| `paths.groupby` | Nests task files in folders by their fields (see below). |
| `loglimit` | How many lines the verb and event logs in `.vex/vexdex` keep (see [[Events and hooks]]). Defaults to 1000. |

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

## The global folder

Besides each project's `.vex`, vex reads a global folder that belongs to you, not to a project or to the install, so it survives upgrades. It is the first of these that exists:

| Where | Used when |
| --- | --- |
| `$VEX_HOME` | set |
| `%APPDATA%\vex` | on Windows |
| `$XDG_CONFIG_HOME/vex` | set |
| `~/.config/vex` | otherwise |

Nothing creates it; make it when you want it. It holds the same things as `.vex`, and a project always wins:

| Path | Effect |
| --- | --- |
| `config.lua` | Read before the project's `config.lua`; the project's value wins for any setting both define. Useful for settings `vex init` does not write, like `paths.groupby`. |
| `tasks/`, `recipes/`, `focuses/`, `views/`, `events/` | Loaded before the same folder in `.vex`, so project extensions can build on them (a task type cannot be defined twice). |
| `plugin/` | Plugins registered at startup. A file named after a slot's default (`canonicalvexid.lua`, `grouppath.lua`...) replaces it for every project; see [[Plugin architecture]]. |

