`.vex/config.lua` is the one configuration file vex actually loads on every run (`src/core/config.lua` registers exactly this path and nothing else). `vex init` writes a default copy:

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
> `default.taskformat`, `default.view`, `default.dataformat`, `default.option`, `default.tasktype`, and both `plugins.*` toggles are written into every new project's `config.lua`, but **nothing in vex reads any of them today** — not `core/view.lua`, not the plugin loader (`plugin:addall` only ever scans vex's own bundled `src/plugin` folder, never a project's `.vex`), nothing. Setting `default.view = 'kanban'`, for instance, has no effect — you still have to name a view explicitly every time (see [[Configuring views]]). Tracked as `implement-config-defaults-1` in the project's own vex tasks.

## What each dead key is *for*, once it's wired up

- `default.taskformat` / `default.dataformat` — would presumably select which [[Plugin architecture|pluggable]] `taskformat`/`dataformat` implementation a project uses. Right now the active one is hardcoded per-run in `src/vex.lua` (`obsidian` and `csvdata` respectively).
- `default.view` — would set the fallback view for `vex view <focus>` with no view name given (today, a lone extra argument to `vex view` is read as the view name, not the focus — see [[CLI reference]]).
- `default.tasktype` — would set what `vextype` a bare `vex add` (no `--vextype`) creates. Today that default (`task`) is hardcoded in `src/core/task.lua`'s `TaskManager:add`, not read from config.
- `plugins.vexations` / `plugins.inline` — would presumably enable or disable the (currently nonexistent) Vexations and inline-mode plugins — see the "Planned / not yet implemented" note in [[CLI reference]].

## See also

- This page is the how-to; [[Configuration]] (under Technical documentation) covers the same file from the internals side, alongside `Config:loadall`'s load-and-merge behaviour.
