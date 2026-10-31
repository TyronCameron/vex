Each `.lua` file in `.vex/events` can register hooks. Every event comes in a pair: `pre-<event>` fires before the action and `post-<event>` after it. For example, `pre-verb-set` fires before the `vex set` command runs, and `post-task-resolve` fires after a task resolves. A hook receives the event's args (see the table below):

```lua
event:on 'post-task-resolve' (function(vexid, t)
    if t.due and t.due < os.time() and t.phase ~= 'final' then
        print(vexid .. ' is overdue')
    end
end)
```

A hook that raises an error stops the command. vex prints which hook failed, on which event, and why, for example `Event hook 'needs-owner' failed on 'pre-verb-set': ...`. A `pre-` hook can therefore enforce project rules before anything changes, for example requiring every task to have an `owner`:

```lua
event:register('pre-task-set', 'needs-owner', function(vexid, properties)
    assert(properties.owner or task:getsingle(vexid).owner, vexid .. ' needs an owner')
end)
```

`event:on '<event>' (fn)` registers an anonymous hook; errors name it by file and line. `event:register(event, handle, fn)` names it: registering the same handle again replaces it, and `event:remove(event, handle)` drops it. A hook on `*` receives every event, with the event's name as its first arg. Hooks run in the order they were registered, which is the order their files load, sorted by path.

## Events

Every event below fires as `pre-` and `post-`.

| Event | Fires around | `pre-` args | `post-` args |
| --- | --- | --- | --- |
| `verb-<verb>` | any command, e.g. `verb-add` | args | args, output |
| `task-add` | creating a task in memory | properties | vexid, task |
| `task-set` | setting fields | vexid, properties, modifiers | vexid, task |
| `task-resolve` | resolving a task | vexid | vexid, task |
| `task-remove` | unlinking a removed task | vexid | vexid |
| `task-delete` | deleting a task's file | vexid | vexid, path |
| `task-forget` | dropping a task from the index, after its file is deleted, gone or unreadable | vexid | vexid |
| `task-refresh` | resolving the tasks whose files changed on disk, before a verb reads its focus | vexids (nil for every task) | vexids, vexids resolved |
| `task-read` | reading a task file | path | path, task (nil if unreadable) |
| `task-write` | writing a task file | vexid | vexid, path |
| `task-move` | moving a task file into place | vexid | vexid, from, to |
| `task-reindexall` | `vex resolve all --force`'s rebuild | | |
| `task-get` | `vex get` on one task | vexid, fields | vexid, fields, output |
| `task-show` | `vex show` on one task | vexid | vexid, output |
| `focus-write` | saving the focus | focus | focus |
| `view-display` | rendering a view | view, focus, flags | view, focus, flags, output |
| `recipe-add` | running a recipe | recipe, properties | recipe, focus |

A verb's `args` are its parsed arguments. `args.raw` is the command line as typed after `vex`, e.g. `set make-coffee-1 --status done`.

See [[Events and hooks]] for the event logs.

## Writing a file

Each example on this page is a complete file: save it as a `.lua` file in `.vex/events` and vex loads it on the next command, with nothing else required. Every file runs with these already in scope, alongside Lua's standard globals: `task` (the task manager), `recipe` (the recipe manager), `focus` (the `Focus` class), `view` (the view manager) and `schema` (the schema library), plus `event` for registering hooks.
