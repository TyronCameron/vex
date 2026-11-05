Every task is validated against the schema of its `vextype` and of each type that type extends (see [[03 Task types (and vexations)]]). This page lists the fields vex defines. Any other field you set is stored as given.

## Fields on every task

| Field | Type | Description |
| --- | --- | --- |
| `vexid` | text | Unique id and filename, generated from the description when the task is added. It can't be changed. |
| `description` | text | Required. At least 2 words and more than 3 characters. |
| `vextype` | text | The task type. Defaults to `task` and must be a registered type. |
| `status` | state | `todo`, then `done`. vex rejects any other move. Defaults to `todo`. Abstracts store none: it is worked out from their children ([[06 Status and state machines]]). |
| `created` | datetime | Set when the task is added. |
| `modified` | datetime | Set on add, and moved to now whenever the task's content changes: a `set` that changes a field, a hand edit, or a value resolution normalises or derives. A `set` that changes nothing, or resolving an unchanged task, leaves it alone. |
| `vexbody` | text | Optional. The markdown body below the frontmatter. |
| `due` | datetime | Optional. |
| `cost`, `benefit` | number | Optional. |
| `owner` | text | Optional. Must be one of the `taskowners` in `.vex/config.lua`. |
| `dependencies` | list of links | Optional. Each entry must be an existing task without `children` or `options`, and dependencies can't form a cycle. |
| `manualtags` | list of tags | Optional. Your own tags, which override the tag rules: `#pinned` always tags the task, `-#review` never does. vex adds a missing `#`, and the last entry for a tag wins (see below). |
| `tags` | list of tags | Worked out on every resolve from the tag rules and `manualtags`, and stored so Obsidian and other tools see it. Edits to it are overwritten. Edit `manualtags` instead. |

Datetimes are stored as timestamps and written as `YYYY-MM-DD HH:MM:SS`. vex reads `YYYY-MM-DD HH:MM:SS` (a `T` may replace the space, the seconds may be left out, and a `Z` or `+HH:MM` zone may follow), `YYYY-MM-DD`, or a phrase such as `tomorrow 8am`, relative to the moment the task is resolved ([[01 CLI reference#Interpreting times]]). A value it can't read fails resolution with an error naming the unknown words, and the task file is left as it was. Links are written as `[[vexid]]`, so the task files form an Obsidian vault.

## Tags

A tag is a `#` and then a word without spaces: `#ThisIsATag`, `#this_is_a_tag` and `#tags/this` are all valid. Each tag on a task is in one of three states:

| State | How | Result |
| --- | --- | --- |
| always | `#x` in `manualtags` | `#x` is in `tags` whatever the rules say. |
| never | `-#x` in `manualtags` | `#x` is not in `tags` whatever the rules say. |
| automatic | not in `manualtags` | `#x` is in `tags` while its rule holds (the `autotags` setting, [[01 Configuring vex (config.lua)#Tagging tasks automatically]]). |

So `tags` is always the rules' tags plus the pinned ones, less the suppressed ones, worked out afresh each time. Changing a rule never loses a tag you set by hand, and `vex resolve all --force` brings every task in line with the new rules.

```console
$ vex set fix-login-1 --insert --manualtags pinned,-review
$ vex set fix-login-1 --insert --manualtags review
$ vex set fix-login-1 --remove --manualtags "#review"
$ vex focus all --contains tags:pinned
```

The first command pins `#pinned` and suppresses `#review`. The second pins `#review` again, replacing `-#review`, because the last entry for a tag wins. The third hands `#review` back to the rules. Write tags without the `#` on the command line or quote them, since an unquoted `#` starts a comment in the shell.

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
| `blockers` | The vexids of the task's `dependencies` that are not `final` yet. |
| `lineage` | The vexids of the abstracts above the task, root first. |
| `backlinks` | The vexids of the tasks that link to the task. |
| `forwardlinks` | The vexids of the tasks the task links to. |
| `path` | Where the task file is. |
| `age` | Whole days since `created`. |
| `implied_due` | The earliest `due` among the task and the open tasks that depend on it, directly or not: a task is needed by the time its soonest dependent is due. Empty when none of them has a due date. |
| `urgency` | The task's rank among its owner's open tasks by `implied_due`, 1 being the most urgent. Tasks without one rank last, and finished tasks have none. |
| `autotags` | The tags whose rule in the `autotags` setting holds for the task. |

Add your own in `.vex/tasks` ([[03 Configuring task types]]).

## Schema and file format

The schema describes the fields, not the file. Task files are markdown with YAML frontmatter because that is the default `taskformat` plugin (`default.obsidian`); another plugin could store the same fields differently. See [[Plugin architecture]].
