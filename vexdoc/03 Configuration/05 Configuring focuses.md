Each `.lua` file in `.vex/focuses` can register named focuses. A named focus is a function that returns a list of tasks, usually built from other focuses:

```lua
focus.register_focus('mine', function()
    return focus.focus('all'):filter('owner', 'alice'):filter('status', 'doing'):get()
end)
```

```txt
vex focus mine --select due
vex view mine kanban
```

A named focus works wherever a focus does: as a starting point, in a list (`mine,all`), and as the value of `--union` and the other set operations. It is evaluated each time it's used, so it always reflects the current tasks.

The query methods match the CLI flags: `filter`, `fuzzy`, `between`, `select`, `tree`, `reversetree`, `backlinks`, `forwardlinks`, `orderby`, `groupby`, `rn`, `interpret`, `complement`, `union`, `intersect`, `xor`, `notin` and `onlyin` (see [[01 CLI reference#Focuses]]). `focus:groups()` returns the tasks as their groups, and `focus:get()` returns them as one list.

The built-in `urgency` transient is a focus of this kind:

```lua
focus.focus('final'):complement():groupby('owner'):orderby('due'):rn():filter('vexid', t.vexid)
```
