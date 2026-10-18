> [!NOTE] Status
> vex v0.0.0, in development.

vex is the embeddable, local-first, markdown-based task system. Every task is a plain-text markdown file with YAML frontmatter, and every project keeps its own `.vex` folder, much like a `.git` folder. There is no server, no daemon and no account.

Because a task is a text file, anything that reads and writes text can work with it: your editor, a shell script, or an AI coding agent.

## Find your way around

- **Getting started**
  - [[01 Installing vex]]: put `vex` on your path and set up shell completion.
  - [[02 Creating your first task using vex]]: the core loop of `init`, `add`, `show`, `set`, `get`, `focus` and `resolve`.
  - [[03 Using a recipe to create a sequence of tasks]]: create a whole structure of tasks in one command.
- **Features**
  - [[01 CLI reference]]: every command and flag.
  - [[02 Frontmatter schema]]: every field a task can hold.
  - [[03 Task types (and vexations)]]: `exploration`, `abstract`, `decision` and `atom`.
  - [[04 Views]]: tables, CSV, JSON, kanban boards, statistics and dependency diagrams.
- **Configuration**
  - [[01 Configuring vex (config.lua)]]: the project config file.
  - [[02 Configuring views]], [[03 Configuring task types]], [[04 Configuring recipes]], [[05 Configuring focuses]] and [[06 Configuring event hooks]]: extending vex from your `.vex` folder.
- **Technical documentation**
  - [[Plugin architecture]]: how each part of vex's behaviour is a swappable plugin.
  - [[The index]] and [[Events and hooks]]: what lives in `.vex/vexdex`.
- [[Vex]]: the original design journal.

## Examples

### A solo developer triaging a backlog

Capture work at whatever level of detail you have:

```txt
vex add Ship the billing rewrite --vextype abstract
vex add Migrate existing invoices
vex add Fix the flaky webhook retry
```

Link the pieces together and move work along:

```txt
vex set ship-billing-rewrite-1 --children migrate-existing-invoices-1,fix-flaky-webhook-retry-1
vex set fix-flaky-webhook-retry-1 --status doing
```

Then review it without opening a file:

```txt
vex view all kanban
vex view ship-billing-rewrite-1 singular
vex view all overview
```

### A team assigning work through git

List the people on the project in `.vex/config.lua`:

```lua
taskowners = {'alice', 'bob'}
```

`owner` must then be one of those names. Assigning work is a commit:

```txt
vex add Write the migration script --owner bob
git commit -am "Assign the migration script to bob" && git push
```

And picking it up is a pull:

```txt
git pull
vex resolve all
vex focus all --filter owner:bob
vex view tabular
```

Git does the syncing and the history; vex keeps the data structured and diffable.

### A repeatable project skeleton

A recipe in `.vex/recipes/release.lua` creates the same structure every time:

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

This creates and links all four tasks, and focuses on them. See [[04 Configuring recipes]].
