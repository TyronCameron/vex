A recipe is a named shortcut for creating a task (or, eventually, a whole structure of tasks) with some fields pre-filled. It's the fastest way to stop retyping the same setup every time you start a certain kind of work.

## Listing recipes

```txt
vex recipe
```

With no recipe name, `vex recipe` lists every recipe currently registered. Today that's just one:

- `abstract` — creates a task with `vextype` forced to `abstract`, i.e. a parent/grouping task. Defined in `src/core/taskdefinitions.lua`.

## Using a recipe

```txt
vex recipe abstract Ship the v0.2 release --status todo
```

Just like `add`, everything up to the first `--flag` becomes the task's `description`; any `--field value` pairs after that are set the same way they would be with `add`. The recipe creates the task, resolves it, prints its `vexid` (e.g. `ship-v02-release-1` — confirmed by testing), and sets your focus to it — so you can immediately follow up with `vex add Write release notes --vextype atom` to capture the next piece of work. Actually nesting it under the abstract's `children` doesn't work yet, no matter how you try to set it — see the warning on [[Frontmatter schema]] and [[Task types]].

## Recipes today vs. recipes tomorrow

Right now, recipes are only defined in vex's own source (as a Lua table with an `add` function — see `src/core/recipe.lua`'s `Recipe:recipe(name)` registration and the `abstract` example above). The `.vex/recipes` folder that `vex init` creates for you is reserved for **project-defined** recipes, but nothing reads from it yet — see [[Configuring recipes]] for the current status and the intended design. Until that lands, "a sequence of tasks" from one recipe invocation means whatever the `abstract` recipe gives you (a single parent task) — chaining several `add` calls after it, as above, gets you the rest of the individual tasks, though not yet linked together as children of it (see [[Task types]] for why).

## Next steps

- [[Task types]] for what `abstract` (and its siblings `decision`, `exploration`, `atom`) are each for.
- [[CLI reference]] for the full `recipe` verb signature.
