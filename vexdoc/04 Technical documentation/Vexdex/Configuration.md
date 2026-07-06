The default `.vex/config.lua` written by `vex init` (`src/core/init.lua`'s `default_config`, serialized with `pretty.table`):

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

`src/lib/config.lua`'s `Config` is a thin key-value store: `registerpath` queues a file, `loadall` `dofile`s each queued path in order and merges its returned table's keys in, with later paths overwriting earlier ones (`core/config.lua` registers exactly one path — `.vex/config.lua` — so there's currently only ever one layer). A missing or unreadable config file just prints a warning and leaves `properties` empty rather than throwing.

Of everything in the shape above, only `taskfolder` is actually read anywhere in the codebase (`core/task.lua`) — see the how-to page, [[Configuring vex (config.lua)]], for the full breakdown of what's real vs. currently inert (`default.*`, `plugins.*`).
