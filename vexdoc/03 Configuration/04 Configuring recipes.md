Each `.lua` file in `.vex/recipes` can register recipes. A recipe is an `add` function that receives the task manager and the properties from the command line, and adds tasks:

```lua
recipe:recipe 'chore' {
    add = function(task, taskproperties)
        taskproperties.vextype = 'atom'
        return {task:add(taskproperties)}
    end
}
```

```txt
vex recipe chore Take out the bins
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
