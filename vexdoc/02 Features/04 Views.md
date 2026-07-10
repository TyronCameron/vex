A view renders whatever tasks a focus resolves to. `vex view <focus> <view>` (or `vex view` alone to list what's available).

```txt
vex view all tabular
```

## `tabular`

A columnar table of every field on every task in the focus (minus `vexbody`, to keep it readable). `config.lua`'s `default.view` key (`table` out of the box — note it doesn't even match the real view name, `tabular`) looks like it should make this the fallback when you don't name a view, but nothing currently reads that key — and there's no way to omit the view name and still get a focus, since a single argument to `vex view` is read as the view name, not the focus. So there's no working "default view" today; name one of the 6 explicitly every time. See [[01 Configuring vex (config.lua)]].

```txt
vexid                vextype   status  owner
make-coffee-wife-1    task      doing   alice
ship-v02-release-1    abstract  todo
```

## `csv`

The same data as `tabular`, as actual comma-separated values (fields are auto-quoted if they contain a comma, quote, or newline) — meant for piping into something like `duckdb`, a spreadsheet, or a script, rather than for reading directly in a terminal.

```txt
vex view all csv > tasks.csv
```

## `json`

A pretty-printed JSON array of the raw task records — useful anywhere you'd reach for a script instead of a shell pipeline.

## `kanban`

Groups tasks into columns by a field (`--field <name>`, defaulting to `status`) and lays them out side by side, one column per distinct value seen.

```txt
vex view all kanban --field status
```

```txt
┌────────────────────┬────────────────────┐
│ todo               │ doing              │
├────────────────────┼────────────────────┤
│ ship-v02-release-1 │ make-coffee-wife-1 │
└────────────────────┴────────────────────┘
```
(Columns are only created for statuses that actually occur in the focus.)

## `overview`

A stats report across the whole focus, in four sections:
- **SCOPE** — a cross-tab of `vextype` × `status`, as a percentage of each type's total, plus a grand total row.
- **QUALITY** — the percentage of tasks with an empty `vexbody`.
- **STRUCTURE** — the percentage of tasks with no `parent` set and no `dependencies` set. (Note: `parent` isn't a schema-validated field — see [[02 Frontmatter schema]] — so this specific stat is only as meaningful as however consistently your project happens to set that key by convention.)
- **MOVEMENT** — the earliest `created` date and the latest `modified` date in the focus.

```txt
vex view all overview
```

## `singular`

A detailed view of exactly one task — it throws an error if the focus resolves to more than one. Shows the task's heading, type, status, and timestamps, then two diagrams:
- **PARENTS** — a top-to-bottom tree from the task's furthest ancestor down to itself, built by reverse-treeing over `children` (see the note on [[03 Vexations (task types)]] about why it's `children`, not a `parent` field).
- **DEPENDENCIES** — a left-to-right chain built by walking `dependencies` in both directions, showing what this task is blocked on and what's blocked on it.

```txt
vex view make-coffee-wife-1 singular
```

```txt
# MAKE-COFFEE-WIFE-1
  task  |  doing
  created: 2026-07-06 03:57

PARENTS

  (no parents)

DEPENDENCIES

  (no dependencies)
```

This is the view [[Home]]'s "solo developer" example leans on to see what's blocked at a glance.
