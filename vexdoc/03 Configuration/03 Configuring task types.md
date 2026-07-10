> [!WARNING] Not yet implemented
> `vex init` creates a `.vex/tasks` folder, described in [[01 CLI reference]] as where "resolution rules" and custom task types would live — but nothing in vex currently reads from it. The four built-in types (`task`, `abstract`, `decision`, `exploration`, `atom`) are registered directly in `src/core/taskdefinitions.lua`. Tracked as `implement-task-type-loader-1` in the project's own vex tasks.

## Intended design

`task:task 'name'` and `:extends 'parent-type'` (`src/core/task.lua`) are the real, working mechanism the built-in types use to declare a schema and inherit from a base type:

```lua
-- src/core/taskdefinitions.lua (real, working code)
task:task 'atom':extends 'task' {
    schema = schema.atleast {
        children = schema.maybe {schema.empty},
    }
}
```

A project-defined type in `.vex/tasks` would presumably follow this same `task:task 'name':extends 'existing-type' { schema = ... }` shape — for example, a `bug` type extending `atom` with an extra `severity` field — loaded automatically instead of requiring a change to vex's own source.

## What exists today instead

Nothing stops you from adding arbitrary extra fields to any task today (see the "not schema-validated yet" section of [[02 Frontmatter schema]]) — you just don't get schema validation or defaults for them until this is implemented. Choosing among the 4 built-in types via `--vextype` (see [[03 Vexations (task types)]]) is the extent of what's configurable today.
