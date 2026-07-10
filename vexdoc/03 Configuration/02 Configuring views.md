> [!WARNING] Not yet implemented
> `vex init` creates a `.vex/views` folder, but nothing in vex currently reads from it. The 6 built-in views (`csv`, `tabular`, `json`, `kanban`, `overview`, `singular`) are registered directly in `src/core/view.lua`. Tracked as `implement-view-loader-1` in the project's own vex tasks.

## Intended design

`View:view(name)` (`src/core/view.lua`) requires a table with a `display(focus, flags)` function — exactly the pattern every built-in view already uses:

```lua
-- src/core/view.lua (real, working code, one of six views defined this way)
v:view 'csv' {
    display = function(focus, flags)
        local tasks = focus:get()
        return format.csv(tasks)
    end
}
```

A project-defined view in `.vex/views` would presumably follow this same `{ display = function(focus, flags) ... end }` shape, loaded automatically and selectable through `vex view <focus> <your-view>` alongside the 6 built-ins.

## What exists today instead

Pick a built-in view explicitly every time: `vex view <focus> <view-name>`, one of the 6 covered in [[04 Views]]. `config.lua`'s `default.view` key looks like it should let you skip naming a view each time, but nothing in vex currently reads `default.view` (or any other key under `default`) — see the callout on [[01 Configuring vex (config.lua)]]. There's also no shorthand for "focus only, default view" today: giving `vex view` exactly one positional argument treats it as the *view* name (defaulting the focus to `prev`), not the other way around — see [[01 CLI reference]].
