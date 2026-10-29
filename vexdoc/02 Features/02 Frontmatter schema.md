Every task is validated against the schema of its `vextype` and of each type that type extends (see [[03 Task types (and vexations)]]). This page lists the fields vex defines. Any other field you set is stored as given.

## Fields on every task

| Field | Type | Description |
| --- | --- | --- |
| `vexid` | text | Unique id and filename, generated from the description when the task is added. It can't be changed. |
| `description` | text | Required. At least 2 words and more than 3 characters. |
| `vextype` | text | The task type. Defaults to `task` and must be a registered type. |
| `status` | state | `todo`, then `doing`, then `done`. vex rejects any other move. Defaults to `todo`. An abstract's `status` is not set by hand: vex works it out from its children (`todo` when every child is in the `initial` phase, `done` when every child is in the `final` phase, `doing` otherwise) and keeps it up to date whenever a child changes. |
| `created` | datetime | Set when the task is added. |
| `modified` | datetime | Updated whenever vex touches the task: on add, set and every resolve, a reindex included. |
| `vexbody` | text | Optional. The markdown body below the frontmatter. |
| `due` | datetime | Optional. |
| `cost`, `benefit` | number | Optional. |
| `owner` | text | Optional. Must be one of the `taskowners` in `.vex/config.lua`. |
| `dependencies` | list of links | Optional. Each entry must be an existing task without `children` or `options`, and dependencies can't form a cycle. Abstracts and decisions can't have any. |

Datetimes are stored as timestamps and written as `YYYY-MM-DD HH:MM:SS`. vex reads `YYYY-MM-DD HH:MM:SS` (a `T` may replace the space), `YYYY-MM-DD`, or a phrase such as `tomorrow 8am`, relative to the moment the task is resolved ([[01 CLI reference#Interpreting times]]). A value it can't read fails resolution with the `uninterpretable` error, and the task file is left as it was. Links are written as `[[vexid]]`, so the task files form an Obsidian vault.

## Fields by type

| Field | Type | Types | Description |
| --- | --- | --- | --- |
| `children` | list of links | `abstract` | The tasks this one groups. Defaults to an empty list. A task can be the child of only one abstract. |
| `options` | list of links | `decision` | Required. The tasks being chosen between. |
| `decision` | link | `decision` | Optional. The chosen option; it must be one of `options`. |

`abstract` and `exploration` tasks must have an empty body. `decision`, `exploration` and `atom` tasks can't have `children`.

## Transients

Transients are fields vex works out each time they are read. They are never stored, and you can use them anywhere a field is accepted: `--filter phase:final`, `--select age`, `vex get --wordcount`.

| Transient | Value |
| --- | --- |
| `wordcount` | The number of words in the description. |
| `phase` | `initial`, `interim` or `final`: where `status` sits in the type's state machine. |
| `lineage` | The vexids of the abstracts above the task, root first. |
| `path` | Where the task file is. |
| `age` | Whole days since `created`. |
| `urgency` | The task's rank among its owner's open tasks by `due`, soonest first: 1 is the most urgent. Tasks without a due date rank last, and finished tasks have none. |

Add your own in `.vex/tasks` ([[03 Configuring task types]]).

## Schema and file format

The schema describes the fields, not the file. Task files are markdown with YAML frontmatter because that is the default `taskformat` plugin (`default.obsidian`); another plugin could store the same fields differently. See [[Plugin architecture]].
