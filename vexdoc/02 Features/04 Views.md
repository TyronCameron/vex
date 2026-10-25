A view renders the tasks in a focus:

```txt
vex view [focus] [view]
```

With no arguments, `vex view` lists the views. With one argument, it is the view, rendering the saved focus. Views show the fields each task stores. A focus built with `--select` shows only the selected fields, transients included.

## `tabular`

A table of every field except the body, formatted for reading. A list shows as its comma-separated values, and a field a task doesn't have is left blank. To fit a terminal, every cell and header is cut to 40 characters, ending in `...`; a list is cut between its values.

```console
$ vex focus all --select vextype,status
Focusing on 3 vexes
$ vex view tabular
┌─────────────────────────────┬──────────┬────────┐
│ vexid                       │ vextype  │ status │
├─────────────────────────────┼──────────┼────────┤
│ fix-flaky-webhook-retry-1   │ task     │ doing  │
│ ship-billing-rewrite-1      │ abstract │ todo   │
│ migrate-existing-invoices-1 │ task     │ todo   │
└─────────────────────────────┴──────────┴────────┘
```

It takes any focus flags (`--select`, `--filter`, `--orderby`, `--groupby` and the rest, see [[01 CLI reference]]), applied in the order given, for this view only: the focus isn't saved, so `prev` stays as it was.

A grouped focus shows each group under a subheader naming its field and value. Each nested level is indented 2 spaces, with a muted guide line down the left:

```console
$ vex view all tabular --groupby vextype:status --orderby vexid --select vextype,status
┌─────────────────────────────────┬──────────┬────────┐
│ vexid                           │ vextype  │ status │
├─────────────────────────────────┼──────────┼────────┤
│ vextype: abstract                                   │
│ │ status: todo                                      │
│ │ │ ship-billing-rewrite-1      │ abstract │ todo   │
│ vextype: task                                       │
│ │ status: doing                                     │
│ │ │ fix-flaky-webhook-retry-1   │ task     │ doing  │
│ │ status: todo                                      │
│ │ │ migrate-existing-invoices-1 │ task     │ todo   │
└─────────────────────────────────┴──────────┴────────┘
```

## `csv`

The same data as comma-separated values, quoted where needed, for spreadsheets, `duckdb` or scripts:

```console
$ vex view all csv > tasks.csv
```

## `json`

The tasks as a JSON array.

## `kanban`

One column per value of a field, `status` by default:

```console
$ vex view all kanban --field status
┌───────────────────────────┬─────────────────────────────┐
│ doing                     │ todo                        │
├───────────────────────────┼─────────────────────────────┤
│ fix-flaky-webhook-retry-1 │ migrate-existing-invoices-1 │
│                           │ ship-billing-rewrite-1      │
└───────────────────────────┴─────────────────────────────┘
```

## `overview`

Statistics for the focus:

- **Scope**: the share of each `vextype` in each `status`, with totals.
- **Quality**: the share of tasks with an empty body.
- **Structure**: the share of tasks with no parent and with no dependencies.
- **Movement**: the earliest `created` and the latest `modified` date.

```console
$ vex view all overview
SCOPE

┌──────────┬───────┬────────┬───────┐
│ vextype  │ doing │ todo   │ total │
├──────────┼───────┼────────┼───────┤
│ abstract │ 0.0%  │ 100.0% │ 1     │
│ task     │ 50.0% │ 50.0%  │ 2     │
│ TOTAL    │ 33.3% │ 66.7%  │ 3     │
└──────────┴───────┴────────┴───────┘

QUALITY

  Tasks with no vexbody: 100.0%

STRUCTURE

  Tasks with nil parent:    33.3%
  Tasks with nil deps:     100.0%

MOVEMENT

  Earliest task created:   2026-10-20
  Latest modification:     2026-10-20
```

## `singular`

Everything about one task. The focus must hold exactly one task.

```console
$ vex view ship-billing-rewrite-1 singular
# SHIP-BILLING-REWRITE-1
  abstract  |  todo
  created: 2026-10-20 10:14

PARENTS

  (none)

CHILDREN

  migrate-existing-invoices-1
  fix-flaky-webhook-retry-1

DEPENDS ON

  (none)

DEPENDED ON BY

  (none)
```

The view shows the task's type, status and dates, then four sections: its parents (from the root down), its children, the tasks it depends on, and the tasks that depend on it.

Add your own views in `.vex/views` ([[02 Configuring views]]).
