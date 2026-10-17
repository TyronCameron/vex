`.vex/config.lua` loads on every command. `vex init` writes a default copy:

```lua
return {
    taskfolder = '.',
    default = {
        taskformat = 'obsidian',
        view = 'table',
        dataformat = 'csv',
        option = 'prev',
        tasktype = 'task'
    },
    plugins = {
        vexations = true,
        inline = true
    }
}
```

## What's actually read

Only **`taskfolder`** — the directory (relative to the project root) where task files live. `src/core/task.lua` reads it directly when resolving where to write and look for tasks. Point it at a subfolder if you'd rather not scatter task files across your whole repo:

```lua
return { taskfolder = 'todo' }
```

(The vault you're reading this in does exactly that — this repo's own `.vex/config.lua` sets `taskfolder = "vexdoc/vex"`, and that folder is where vex's own backlog, including the tasks tracking every gap mentioned on this page, actually lives.)

## Grouping task files into folders

**`paths.groupby`** nests task files in folders by any of their fields, transients included. It's a list, and each entry adds a level of folders, in order:

```lua
return {
    taskfolder = 'todo',
    paths = {
        groupby = {'lineage', 'status'},
    },
}
```

With that config, a task sits under its ancestors (the `lineage` transient: the abstracts whose `children` hold it, root first), then in a folder named after its status: `todo/version-01-1/doing/implement-config-defaults-1.md`.

- A list value (like `lineage`) nests one folder per element; unset values and empty lists add no folder.
- Characters that can't be in a folder name (`/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`) become `-`, so every value stays a single folder inside `taskfolder`.
- Files move as soon as anything they depend on changes: `vex set`, `vex add`, `vex resolve <vexid>` or `vex remove`. Changing a task moves the files of every task it links to, so editing a parent's `children` moves its children's files. Empty folders left behind are removed.
- vex owns the layout. If you move a task file by hand, vex still finds it, and moves it back the next time that task (or one linking to it) is resolved.
- After adding, changing or removing `paths.groupby`, run `vex resolve all` to move every existing file into place. Without `paths.groupby`, task files sit flat at `<vexid>.md`.

> [!WARNING] Everything else in the default config is currently inert
> `default.taskformat`, `default.view`, `default.dataformat`, `default.option`, `default.tasktype`, and both `plugins.*` toggles are written into every new project's `config.lua`, but **nothing in vex reads any of them today** — not `core/view.lua`, not the plugin loader (`plugin:addall` only ever scans vex's own bundled `src/plugin` folder, never a project's `.vex`), nothing. Setting `default.view = 'kanban'`, for instance, has no effect — you still have to name a view explicitly every time (see [[02 Configuring views]]). Tracked as [[implement-config-defaults-1]].

