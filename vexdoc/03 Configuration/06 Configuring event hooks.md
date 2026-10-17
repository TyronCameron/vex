Each `.lua` file in `.vex/events` can register hooks. Every command fires two events, `pre-<command>` before it runs and `post-<command>` after, such as `pre-add` and `post-resolve`. A hook receives the focus the command acts on:

```lua
event:on 'post-resolve' (function(focus)
    focus:each_task(function(t)
        if t.due and t.due < os.time() and t.phase ~= 'final' then
            print(t.vexid .. ' is overdue')
        end
    end)
end)
```

A `pre-` hook that raises an error stops the command before it changes anything, so hooks can enforce project rules on top of resolution, for example requiring every task to have an `owner`:

```lua
event:on 'pre-set' (function(focus)
    focus:each_task(function(t)
        assert(t.owner, t.vexid .. ' needs an owner')
    end)
end)
```

Hooks for the same event run in the order their files load, sorted by path. See [[Events and hooks]] for how events are dispatched.
