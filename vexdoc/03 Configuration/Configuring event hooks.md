> [!WARNING] Not yet implemented
> `vex init` creates a `.vex/events` folder, but nothing in vex currently reads from it. `src/lib/event.lua` — the module that would dispatch hooks — is a stub that just `return {}`. Tracked as `implement-event-hooks-1` in the project's own vex tasks.

## Intended design

Per [[Vex]]'s design notes, every verb would fire two events: `pre-<verb>` and `post-<verb>` (e.g. `pre-add`, `post-resolve`). A hook would be a Lua function taking the task (or focus) being acted on, registered from a file in `.vex/events`:

```lua
-- .vex/events/on-resolve.lua (illustrative — this file is not read today)
return {
    ["post-resolve"] = function(task)
        -- e.g. reject a resolve that leaves a due date in the past
    end
}
```

The intent is that hooks would let a project enforce its own rules on top of vex's built-in [[CLI reference#Resolution|resolution]] — for example, rejecting a task with no `owner`, or auto-tagging tasks created from a certain folder.

## What exists today instead

There's no per-project hook mechanism yet. The closest thing you can do today is external: run `vex resolve all` as a `git pre-commit` step (see [[CLI reference]]) and let a non-zero exit code from vex block the commit — that gives you validation-as-a-gate without needing hooks wired into vex itself.

## See also

- [[Events and hooks]] — the technical-documentation counterpart, covering the internals of the (currently empty) hook dispatch module.
