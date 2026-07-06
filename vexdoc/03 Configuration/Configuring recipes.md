> [!WARNING] Not yet implemented
> `vex init` creates a `.vex/recipes` folder, but nothing in vex currently reads from it — the only recipe that exists is `abstract`, registered directly in `src/core/taskdefinitions.lua`. Tracked as `implement-recipe-loader-1` in the project's own vex tasks.

## Intended design

`Recipe:recipe(name)` (`src/core/recipe.lua`) requires a table with an `add` function — this is precisely how the built-in `abstract` recipe is defined:

```lua
-- src/core/taskdefinitions.lua (real, working code — the pattern a project recipe would presumably follow)
recipe:recipe 'abstract' {
    add = function(task, taskproperties)
        taskproperties.vextype = 'abstract'
        return task:add(taskproperties)
    end
}
```

A project-defined recipe in `.vex/recipes` would presumably be a Lua file following the same `{ add = function(task, taskproperties) ... end }` shape, loaded and registered automatically the way vex's own built-in plugins are (see [[Plugin architecture]]) — letting `vex recipe <name>` create more than a single task (e.g. a whole milestone skeleton) in one call.

## What exists today instead

`vex recipe abstract <Description>` gives you a single pre-typed parent task. Building out the rest of a repeatable structure means adding the remaining tasks by hand — wiring them into the abstract's `children` isn't possible yet, by any means, today (see [[Frontmatter schema]]'s warning) — see [[Using a recipe to create a sequence of tasks]] for the full walkthrough.
