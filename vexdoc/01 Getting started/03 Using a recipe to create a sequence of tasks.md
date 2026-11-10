A recipe is a named shortcut that creates one or more tasks with fields already filled in. Use one whenever you set up the same kind of work repeatedly.

## Listing recipes

```console
$ vex recipe
Available recipes:
  abstract
  recurring
  repeat
```

With no name, `vex recipe` lists the recipes available. vex ships three:

- `abstract` creates a task of type `abstract`: a parent that groups other tasks.
- `recurring` creates a task that comes back each time you finish it (see below).
- `repeat` creates the same task `--n` times.

## Using a recipe

```console
$ vex recipe abstract Ship the v0.2 release
ship-v0-2-release-1
```

As with `add`, every word up to the first `--flag` is the description, and flags set fields. vex creates, resolves and writes every task the recipe adds, prints their vexids, and focuses on them.

## Recurring tasks

```console
$ vex recipe recurring Wash the dishes --start today --recur weekly
wash-dishes-1
wash-dishes-2
```

`--recur` says how often the task comes back: `hourly`, `daily`, `weekly`, `fortnightly`, `monthly`, `yearly`, or a length such as `3 days` or `2 weeks`. `--over` names the date field it moves along, `due` unless you say otherwise, and `--start` sets that field on the first task.

The recipe adds an abstract, `wash-dishes-1`, and the first task inside it, `wash-dishes-2`. When that task reaches a final status (`done`), vex adds the next one, `wash-dishes-3`, to the same abstract. The new task has the same description, body and fields, starts at the initial status, and its `due` is a week after the finished task's. This happens however the task got there: `vex set`, or an edit to the file that vex picks up. With the `vexations` plugin switched off, the recipe adds the task alone, without the abstract.

The recipe only fills in two fields, `recur` and `over`, so you can make any task recur: `vex set water-plants-1 --recur "3 days"`.

## Repeating a task

```console
$ vex recipe repeat Stretch the hamstrings --n 3
stretch-hamstrings-1
stretch-hamstrings-2
stretch-hamstrings-3
stretch-hamstrings-4
```

`repeat` adds an abstract and `--n` copies of the task inside it (just the copies without `vexations`). Every other flag sets a field on each copy.

## Writing your own

A recipe is a Lua file in `.vex/recipes`. This one creates a release with three linked stages:

```lua
recipe:recipe 'release' {
    add = function(task, taskproperties)
        local name = taskproperties.description
        local release = task:add({description = name, vextype = 'abstract'})
        local stages = {}
        for _, stage in ipairs({'Spike', 'Build', 'Test'}) do
            table.insert(stages, task:add({description = stage .. ' ' .. name, vextype = 'atom', parent = release}))
        end
        return {release, unpack(stages)}
    end
}
```

```console
$ vex recipe release the payments API
payments-api-1
spike-payments-api-1
build-payments-api-1
test-payments-api-1
```

See [[04 Configuring recipes]] for the details.

## Next steps

- [[03 Task types (and vexations)]] for what `abstract`, `decision`, `exploration` and `atom` are for.
- [[01 CLI reference]] for the `recipe` command.
