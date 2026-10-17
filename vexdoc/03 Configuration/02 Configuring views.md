Each `.lua` file in `.vex/views` can register views. A view is a `display` function that takes the focus and the command's flags and returns the text to print:

```lua
view:view 'count' {
    display = function(focus, flags)
        return #focus:get() .. ' tasks'
    end
}
```

```txt
vex view all count
```

`focus:get()` returns the focus's tasks. Read any field from them, transients included. Flags arrive as a table: `vex view all count --field status` gives `flags.field == 'status'`.

A view only presents tasks: choose which tasks with a focus, and keep the view to formatting them. Views load after task types, recipes and focuses, and a view with the name of a built-in replaces it.

Set `default.view` in `.vex/config.lua` to make your view the default ([[01 Configuring vex (config.lua)]]).
