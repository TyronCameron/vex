> [!WARNING] Not yet implemented
> `vex init` creates a `.vex/focuses` folder, but nothing in vex currently reads from it — the only named focuses that exist are the ones hardcoded in `src/core/focus.lua` (`all`, `none`, `updated`, `prev`). Tracked as `implement-focus-loader-1` in the project's own vex tasks.

## Intended design

`Focus.register_focus(name, get)` (`src/core/focus.lua`) is the exact mechanism the 4 built-in named focuses already use — each one is just a name paired with a function that returns a list of tasks. A project-defined focus in `.vex/focuses` would presumably follow the same shape:

```lua
-- .vex/focuses/mine.lua (illustrative — this file is not read today)
return function()
    -- e.g. everything owned by whoever's running vex, still todo
    return require('core.focus').getalltasks()
end
```

...loaded and registered automatically alongside the built-ins, so `vex focus mine` would work the same way `vex focus all` does today.

## What exists today instead

You can't name and save a custom focus for reuse under your own name yet. What you *can* do is build the equivalent query inline every time, starting from a real named focus and chaining flags:

```txt
vex focus all --filter owner:alice --filter status:doing
```

...and rely on `prev` (the persisted result of your last `vex focus` call) to avoid retyping it in the very next command. See [[CLI reference#Focuses]] for the full flag list, and [[Home]] for a worked example of this pattern.
