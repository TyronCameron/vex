Each `.lua` file in `.vex/recipes` can register recipes. A recipe is an `add` function that receives the task manager and the properties from the command line, and adds tasks:

```lua
recipe:recipe 'chore' {
    add = function(task, taskproperties)
        taskproperties.vextype = 'atom'
        return {task:add(taskproperties)}
    end
}
```

```console
$ vex recipe chore Take out the bins
```

`taskproperties` holds the description and every flag. `add` returns the list of vexids it added. A recipe can add as many tasks as it likes and link them through their fields; vex resolves and writes each returned task in the order of the list, then focuses on all of them:

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

The built-in `abstract` recipe is defined the same way.

## Writing a file

Each example on this page is a complete file: save it as a `.lua` file in `.vex/recipes` and vex loads it on the next command, with nothing else required. Every file runs with these already in scope, alongside Lua's standard globals: `task` (the task manager), `recipe` (the recipe manager), `focus` (the `Focus` class), `view` (the view manager) and `schema` (the schema library).
