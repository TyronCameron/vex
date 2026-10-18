Every task has a `vextype`. The base type is `task`. The vexations plugin adds four types on top of it, each answering a different question about the work. Every type keeps all of `task`'s fields (see [[02 Frontmatter schema]]).

| `vextype` | Answers | Body | Structure |
| --- | --- | --- | --- |
| `exploration` | What do I need to know? | Empty | No `children` |
| `abstract` | What needs to happen? | Empty | `children`: the tasks it groups |
| `decision` | Which path do we take? | Free | `options`, and a `decision` from among them |
| `atom` | What do I actually do? | Free | No `children` |

### Exploration

Use an exploration when you don't yet know what needs to happen. The task marks an open question. The exploring itself happens in your notes or an outliner, so the body stays empty.

### Abstract

An abstract groups other tasks through its `children` and holds nothing else. Capture the shape of the work first and fill it in later:

```txt
vex add Ship the beta --vextype abstract
vex set ship-beta-1 --insert --children write-release-notes-1
```

Parents are always found through `children`. `--reversetree children` walks up from a task, and the `lineage` transient lists its abstracts.

### Decision

Use a decision when the path forward branches. `options` lists the candidate tasks, often atoms, and `decision` records the choice:

```txt
vex add Choose a database --vextype decision --options use-postgres-1,use-sqlite-1
vex set choose-database-1 --decision use-sqlite-1
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
