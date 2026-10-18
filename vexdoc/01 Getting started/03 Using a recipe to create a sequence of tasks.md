A recipe is a named shortcut that creates one or more tasks with fields already filled in. Use one whenever you set up the same kind of work repeatedly.

## Listing recipes

```txt
vex recipe
```

With no name, `vex recipe` lists the recipes available. vex ships `abstract`, which creates a task of type `abstract`: a parent that groups other tasks.

## Using a recipe

```txt
vex recipe abstract Ship the v0.2 release
```

As with `add`, every word up to the first `--flag` is the description, and flags set fields. vex creates, resolves and writes every task the recipe adds, prints their vexids, and focuses on them.

## Writing your own

A recipe is a Lua file in `.vex/recipes`. This one creates a release with three linked stages:

```lua
recipe:recipe 'release' {
    add = function(task, taskproperties)
        local name = taskproperties.description
        local stages = {}
        for _, stage in ipairs({'Spike', 'Build', 'Test'}) do
            table.insert(stages, task:add({description = stage .. ' ' .. name, vextype = 'atom'}))
        end
        local release = task:add({description = name, vextype = 'abstract', children = stages})
        return {release, unpack(stages)}
    end
}
```

```txt
vex recipe release the payments API
```

See [[04 Configuring recipes]] for the details.

## Next steps

- [[03 Task types (and vexations)]] for what `abstract`, `decision`, `exploration` and `atom` are for.
- [[01 CLI reference]] for the `recipe` command.
