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

> [!WARNING] Everything else in the default config is currently inert
> `default.taskformat`, `default.view`, `default.dataformat`, `default.option`, `default.tasktype`, and both `plugins.*` toggles are written into every new project's `config.lua`, but **nothing in vex reads any of them today** — not `core/view.lua`, not the plugin loader (`plugin:addall` only ever scans vex's own bundled `src/plugin` folder, never a project's `.vex`), nothing. Setting `default.view = 'kanban'`, for instance, has no effect — you still have to name a view explicitly every time (see [[02 Configuring views]]). Tracked as `implement-config-defaults-1` in the project's own vex tasks.

## See also

- This page is the how-to; [[Configuration]] (under Technical documentation) covers the same file from the internals side, alongside `Config:loadall`'s load-and-merge behaviour.
