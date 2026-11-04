`config.lua` returns a Lua table and is read on every command, from the global folder and from every `.vex` folder above where you run vex (see [[01 Configuring vex (config.lua)#Layers]]). Settings you leave out take the defaults. `vex init` writes this one into `.vex/config.lua`:

```lua
return {
    taskfolder = '.',
    default = {
        tasktype = 'task'
    },
    taskowners = {},
    loglimit = 100,
    paths = {
        groupby = {'status', 'lineage'}
    },
    fingerprint = {
        exclude = {'modified'}
    }
}
```

This repository's own config sets `taskfolder = "vexdoc/vex"`: its backlog is the `vex` folder of this wiki.

## Settings

| Setting | Effect |
| --- | --- |
| `taskfolder` | The folder, relative to the project root, that holds the task files. |
| `taskowners` | The names `owner` may take. With no task owners, tasks can't have an owner. |
| `default.tasktype` | The `vextype` of a task added without one. |
| `paths.groupby` | Nests task files in folders by their fields (see below). |
| `loglimit` | How many lines the verb and event logs in `.vex/vexdex` keep (see [[Events and hooks]]). Defaults to 100. |
| `plugins` | Chooses what fills each plugin slot and switches standalone plugins off (see [[01 Configuring vex (config.lua)#Plugins]]). |
| `fingerprint.exclude` | Fields whose changes don't count as a change to the task, so they never move `modified` on their own (see [[Resolution pipeline#Fingerprints and `modified`]]). They are still written to the file. `vex init` sets it to `{'modified'}`. |

For example, to keep tasks in a `todo` folder and assign them to two people:

```lua
return {
    taskfolder = 'todo',
    taskowners = {'alice', 'bob'},
}
```

`taskfolder` is a path relative to the project, and vex tidies it: backslashes become `/`, and `./`, repeated slashes and a trailing slash are dropped, so `'ehvilee/tasks/'`, `'./ehvilee//tasks'` and `'ehvilee\\tasks'` all mean `ehvilee/tasks`. An absolute path is refused. A setting of the wrong kind, such as `loglimit = 'lots'`, stops the command with a message naming the setting, and so does a config file that isn't valid Lua or doesn't return a table.

## Layers

vex reads these `config.lua` files, in order, and each one overrides the settings before it:

1. The global folder's (see [[01 Configuring vex (config.lua)#The global folder]]).
2. The `.vex/config.lua` of every folder above your project, from the outermost to the innermost.
3. Your project's own `.vex/config.lua`.

Tables merge key by key, so a project can change `paths.groupby` and keep the rest of `paths`. Lists and empty tables replace the earlier value outright: `taskowners = {'carol'}` drops the owners an outer config listed, and `paths = { groupby = {} }` turns grouping off. `taskfolder` is always relative to the innermost project, so an outer config can only give a default. `vex init` writes every setting into `.vex/config.lua`, which pins each of them for that project; delete a line to inherit it from an outer layer.

A `.vex` folder in a parent folder is a layer for everything below it: its `config.lua`, its extension folders (`tasks/`, `recipes/`, `focuses/`, `views/`, `events/`) and its `plugin/` folder. Extensions load from the outermost layer first, so inner ones can build on them.

## Plugins

`plugins` chooses which plugin does each job and switches standalone plugins off (see [[Plugin architecture]]):

```lua
return {
    plugins = {
        tagger = 'shorttag',
        vexcomplete = false,
    },
}
```

- `slot = 'name'` makes `name` the active member of a slot (`tagger`, `taskpath`, `taskformat`, `sortdata`, `frontmatter` or `body`). The plugin can be one of vex's own or a file of that name in a `plugin` folder: `.vex/plugin/shorttag.lua` here.
- `name = false` switches a standalone plugin off, so its verbs and task types aren't registered, and `name = true` leaves it on. `vexcomplete` provides the shell completion verbs, and `vexations` the `abstract`, `decision`, `exploration` and `atom` task types, so `vexations = false` leaves you with plain `task`s. Tasks that already use a type that is switched off fail to resolve with an unknown task type error.
- A name that isn't a plugin or slot, or switching off a plugin that fills a slot, stops the command with the `bad-plugin-setting` error.

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

With this config, a task sits under its ancestors and then in a folder named after its status: `todo/version-01-1/done/implement-config-defaults-1.md`.

- A list value such as `lineage` adds one folder per element. Unset values and empty lists add none.
- Characters that can't appear in a folder name (`/ \ : * ? " < > |`) become `-`.
- Files move whenever something they depend on changes. Resolving a task resolves and re-files every task linked to it or from it, transitively: editing a parent's `children` moves its children, and finishing a dependency moves its dependents. Empty folders are removed.
- vex owns the layout. A file moved by hand is still found, and is moved back the next time it is resolved.
- After changing `paths.groupby`, run `vex resolve all --force` to move the existing files. Without `paths.groupby`, task files sit flat at `<vexid>.md`.

## The global folder

Besides each project's `.vex` (and those above it), vex reads a global folder that belongs to you, not to a project or to the install, so it survives upgrades. It is the first of these that exists:

| Where | Used when |
| --- | --- |
| `$VEX_HOME` | set |
| `%APPDATA%\vex` | on Windows |
| `$XDG_CONFIG_HOME/vex` | set |
| `~/.config/vex` | otherwise |

Nothing creates it; make it when you want it. It holds the same things as `.vex`, and a project always wins:

| Path | Effect |
| --- | --- |
| `config.lua` | Read before the project's `config.lua`; the project's value wins for any setting both define. Useful for settings you want in every project. |
| `tasks/`, `recipes/`, `focuses/`, `views/`, `events/` | Loaded before the same folder in `.vex`, so project extensions can build on them (a task type cannot be defined twice). |
| `plugin/` | Plugins registered at startup. A file named after a slot's default (`canonicalvexid.lua`, `grouppath.lua`...) replaces it for every project; a file with a new name can be selected with `plugins`; see [[Plugin architecture]]. |

