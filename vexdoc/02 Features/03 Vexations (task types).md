Every task has a `vextype`. The base type is just `task`, but vexations ships four opinionated subtypes that each answer a different question.

You can create your own subtypes too (see [[03 Configuring task types]] for the current status of doing that from a project rather than from vex's own source).

## The four built-in types

| `vextype`     | Answers                          | Body                          | Structural field                              |
| ------------- | ---------------------------------- | -------------------------------- | ---------------------------------------------- |
| `exploration` | *What do I need to know?*         | Must be empty                   | No `children` allowed                          |
| `abstract`    | *What needs to happen?*           | Must be empty                   | `children` — a list of task links              |
| `decision`    | *Which path do we take?*          | Free-form                       | `options` (required) and `decision` (must be one of `options`) |
| `atom`        | *What do I actually do?*          | Free-form                       | No `children` allowed                          |

All four still carry the base `task` fields (`due`, `dependencies`, `cost`, `benefit`, etc. — see [[02 Frontmatter schema]]) on top of the above.

> [!WARNING] `abstract` and `decision` are confirmed broken across more than one resolve
> Every field that actually links tasks together (`children`, `dependencies`, `options`) currently fails to survive being written to disk and read back — see the callout on [[02 Frontmatter schema]]. In practice: an `abstract` task can be created, but the *next* `vex resolve all` fails on it, forever, and a `decision` task can't be created at all (its `options` is required and can never be populated). `exploration` and `atom` don't use those fields structurally, so they're unaffected.

### Exploration

For when the landscape itself is uncertain — you don't yet know what needs to happen, only that something needs figuring out first. An exploration's body is required to be empty by schema, on the theory that the exploring happens in an outliner or in your notes, and the task file itself is just a marker that the question exists and hasn't been answered yet.

### Abstract

A container. An abstract holds no information of its own — schema forces its body to stay empty — it exists purely to group other tasks together via its `children` list. Fast to create (`vex add "Ship v0.2" --vextype abstract`, confirmed working), meant to be: jot down the shape of the work now, decompose it into `atom`/`decision`/`exploration` children later. In practice today, decompose it fast, too — see the warning above about what happens on the next resolve.

> [!NOTE] Children, not parent
> The tree/reversetree machinery ([[01 CLI reference]]'s `--tree`/`--reversetree`, and the `singular` [[04 Views|view]]'s parent diagram) is *designed* to walk the `children` list on the *abstract*, not a `parent` field on the child — though see the warning above about whether `children` currently holds anything at all.

### Decision

For when the path forward branches and something — you, a teammate, or a future you — needs to actually choose. A decision's `options` list is a set of other tasks (often `atom`s representing the different paths), and its `decision` field, once set, must be one of those options. Nothing else in vex enforces *when* a decision gets made — resolution only checks that `decision`, if present, is a legal choice. **Confirmed by testing: you can't create one at all today** — `options` is required with no default, and required list fields can never be populated (see the warning above), so `vex add ... --vextype decision` fails resolution immediately, before any file is written.

### Atom

A single, fully-specified, doable action. No `children` — if you find yourself wanting to break an atom down further, that's a sign it should have been an `abstract` instead. Atoms are where `dependencies` and `due` dates are *meant* to matter most, since they're the leaves of the graph that `--tree`/`--reversetree` walk — though both `dependencies` (see the warning above) and `due` (see [[02 Frontmatter schema]]) are currently confirmed broken, so an atom on its own (description, status, cost/benefit) is what actually works today.

### How they chain together

A common shape, borrowed from [[Vex]]'s own design notes: an `abstract` for the overall goal, an `exploration` child while the approach is still unclear, a `decision` once the exploration turns up more than one viable path, and `atom`s (with `dependencies` between them) once the decision is made. There's no automation that creates this chain for you today — each task would be added by hand and linked via `children`/`options`/`dependencies` — but right now none of those linking fields actually work (see the warnings above), so the four types exist as loose, unconnected tasks in practice until `fix-list-field-roundtrip-1` lands.

## Custom types

`task:task 'name':extends 'existing-type' { schema = ... }` (in vex's own Lua source) is how the four built-ins above are defined, and it's the same mechanism a project-specific type would use. Today that means writing Lua against `src/core/taskdefinitions.lua`'s pattern directly; a project-local way to register new types from `.vex/tasks` is planned but not wired up yet — see [[03 Configuring task types]].
