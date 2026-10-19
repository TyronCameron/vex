---
vexid: let-task-types-register-hooks-1
vextype: atom
description: Let task types register hooks that receive the task manager and focus
created: "2026-10-19 21:29:42"
modified: "2026-10-19 21:29:42"
status: todo
---

Event hooks ([[06 Configuring event hooks]]) are global. A `.vex/events` file registers on an event name, gets bare args such as `(vexid, task)`, and has to filter by type itself. Recurrence, and other per-type behaviour, needs hooks that belong to a task type. Let a type declare hooks next to its schema, inherited down the type chain like schemas and transients (`TaskManager:schemaof`, `transientof`):

```lua
task:task 'chore':extends 'atom' {
    schema = ...,
    hooks = {
        ['post-task-resolve'] = function(t, ctx) ... end,
    },
}
```

The handler gets the task and a context carrying the task manager and `focus`, so it can add or change other tasks without reaching for globals. It also gets the previous indexed version, so it can compare before and after. Decide whether these register through `lib.event` (filtered to the type's tasks) or run from `TaskManager` directly, keeping `hook-failed` semantics either way. Document it in [[03 Configuring task types]], and test it in `test/unit/core/task_spec.lua` and `test/e2e/extensions_spec.lua`.
