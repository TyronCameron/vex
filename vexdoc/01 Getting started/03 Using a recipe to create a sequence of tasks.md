A recipe is a named shortcut for creating a whole structure of tasks, with fields pre-filled. It's the fastest way to stop retyping the same setup every time you start a certain kind of work.

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

Just like `add`, everything up to the first `--flag` becomes the task's `description`; any `--field value` pairs after that are set the same way they would be with `add`. The recipe creates the task, resolves it, prints its `vexid`, and sets your focus to it — so you can immediately follow up with `vex add Write release notes --vextype atom` to capture the next piece of work. 

## Next steps

- [[03 Vexations (task types)]] for what `abstract` (and its siblings `decision`, `exploration`, `atom`) are each for.
- [[01 CLI reference]] for the full `recipe` verb signature.
