Each `.lua` file in `.vex/focuses` can register named focuses. A named focus is a function that returns a list of tasks, usually built from other focuses:

```lua
focus.register_focus('mine', function()
    return focus.focus('all'):filter('owner', 'alice'):filter('status', 'done'):get()
end)
```

```console
$ vex focus mine --select due
$ vex view mine kanban
```

A named focus works wherever a focus does (see [[05 Getting into focus]]): as a starting point, in a list (`mine,all`), and as the value of `--union` and the other set operations. It is evaluated each time it's used, so it always reflects the current tasks.

The query methods match the CLI flags: `filter`, `nil`, `fuzzy`, `between`, `select`, `step`, `tree`, `reversetree`, `orderby`, `groupby`, `rn`, `first`, `last`, `interpret`, `complement`, `union`, `intersect`, `xor`, `notin` and `onlyin` (see [[01 CLI reference#Focuses]]). After `groupby`, `focus:groups()` returns the tasks as their groups; `focus:get()` always returns them as one list.

The built-in `urgency` transient is a focus of this kind:

```lua
focus.focus('final'):complement():groupby('owner'):orderby('due'):rn():filter('vexid', t.vexid)
```

## Writing a file

Each example on this page is a complete file: save it as a `.lua` file in `.vex/focuses` and vex loads it on the next command, with nothing else required. Every file runs with these already in scope, alongside Lua's standard globals: `task` (the task manager), `recipe` (the recipe manager), `focus` (the `Focus` class), `view` (the view manager) and `schema` (the schema library).
