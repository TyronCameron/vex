Every task has a `vextype`. The base type is `task`. The vexations plugin adds four types on top of it, each answering a different question about the work. It ships with vex and is on by default; `plugins = { vexations = false }` in `config.lua` switches it off and leaves only `task` (see [[01 Configuring vex (config.lua)#Plugins]]). Every type keeps all of `task`'s fields (see [[02 Frontmatter schema]]).

| `vextype` | Answers | Body | Structure |
| --- | --- | --- | --- |
| `exploration` | What do I need to know? | Empty | No children |
| `abstract` | What needs to happen? | Empty | Children: the tasks it groups |
| `decision` | Which path do we take? | Free | Children: its options, and a `decision` from among them |
| `atom` | What do I actually do? | Free | No children |

A task joins a group by naming it as its `parent`. The group's `children` are worked out from that, never stored.

### Exploration

Use an exploration when you don't yet know what needs to happen. The task marks an open question. The exploring itself happens in your notes or an outliner, so the body stays empty.

### Abstract

An abstract groups the tasks that name it as their `parent`, and holds nothing else. Capture the shape of the work first and fill it in later:

```console
$ vex add Ship the beta --vextype abstract
ship-beta-1
$ vex add Write the release notes --vextype atom --parent ship-beta-1
write-release-notes-1
$ vex set fix-login-1 --parent ship-beta-1
```

An abstract's `status` is worked out from its children ([[06 Status and state machines]]). Nothing can depend on an abstract or a decision: depend on the atoms under it.

A task has at most one `parent`, and a task can't sit under itself or one of its own descendants (`parent-cycle`). `--tree parent` walks up from a task, `--tree children` walks down, and the `lineage` transient lists its ancestors, root first. Explorations and atoms take no children: once a task names one as its `parent`, the atom or exploration fails to resolve with `has-children`. Nothing may depend on a task with children, so a task can't sit under a task that another task depends on either (`dependency-with-children`).

### Decision

Use a decision when the path forward branches. Its children are the candidate tasks, often atoms, and `decision` records the choice:

```console
$ vex add Choose a database --vextype decision
choose-database-1
$ vex set use-postgres-1,use-sqlite-1 --parent choose-database-1
$ vex set choose-database-1 --decision use-sqlite-1
```

### Atom

An atom is one concrete, doable action. If you want to break an atom down, it should have been an abstract. Atoms are where `due` and `dependencies` matter most.

### How they fit together

A typical piece of work starts as an abstract with an exploration under it. When the exploration turns up more than one approach, a decision follows, and once that's made, atoms carry out the chosen path, with `dependencies` between them.

## Custom types

Define your own types in `.vex/tasks`, extending any existing type:

```lua
task:task 'bug':extends 'atom' {
    schema = schema.atleast { severity = schema.any {'low', 'high'} }
}
```

See [[03 Configuring task types]].

## Upgrading from `children` and `options`

Earlier versions of vex stored the hierarchy the other way round: an abstract listed its `children` and a decision its `options`. To move a project's task files over, run this once from the project root, with `<taskfolder>` set to your `taskfolder` and the script in the `scripts` folder of a vex clone:

```console
$ luajit scripts/migrate-parents.lua <taskfolder>
$ vex resolve all --force
```

The script gives each listed task a `parent` and drops the lists. It changes nothing if a task is listed twice or a listed task has no file, and says which. Running it again does nothing. Children and options no longer keep the order they were listed in.
