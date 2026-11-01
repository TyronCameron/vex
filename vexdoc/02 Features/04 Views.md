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
│ fix-flaky-webhook-retry-1   │ task     │ done   │
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
│ │ status: done                                      │
│ │ │ fix-flaky-webhook-retry-1   │ task     │ done   │
│ │ status: todo                                      │
│ │ │ migrate-existing-invoices-1 │ task     │ todo   │
└─────────────────────────────────┴──────────┴────────┘
```

## `csv`

The same data as comma-separated values, for spreadsheets, `duckdb` or scripts. Like the other views it leaves out the body, which lives only in the task file. Dates are written as in the task file (`2026-10-31 08:00:00`) and a list such as `children` is one cell of comma-separated values. A cell holding a comma, a double quote, a line break or leading or trailing spaces is wrapped in double quotes, with each quote inside doubled, so any CSV reader gets the fields back as they are:

```console
$ vex view all csv > tasks.csv
```

### Piping vex into other tools

Everything vex prints is plain text on standard output, so it pipes into whatever you already use. For instance, count the tasks in each status with `duckdb`:

```console
$ vex view all csv | duckdb -c "select status, count(*) cnt from read_csv('/dev/stdin') group by status order by status"
```

The `json` view works the same way with `jq`:

```console
$ vex view all json | jq -r '.[] | select(.status == "todo") | .vexid'
```

## `ics`

The tasks as an iCalendar file that any calendar app can import. Each task holding a value in the date field becomes one event, and tasks without one are skipped. The field is `due` unless you pick another `date` or `datetime` field with `--by`, custom task types' fields included; any other field fails with `not-a-date-field`:

```console
$ vex view all ics > tasks.ics
$ vex view all ics --by created > created.ics
```

An event holds:

- `UID` as `<vexid>@vex`, so importing the file again updates the events instead of duplicating them.
- `SUMMARY`, the task's description.
- `DTSTART` in UTC. A value at midnight becomes an all-day event with a `DTEND` of the next day.
- `CREATED`, `LAST-MODIFIED` and `DTSTAMP`.
- `CATEGORIES`, the task's type and owner.
- `RELATED-TO` the parent task, when it has one.
- `DESCRIPTION`, a `field: value` line for every other field the task stores. The body is left out.

## `json`

The tasks as a JSON array, without their bodies.

## `kanban`

One column per value of a field, `status` by default:

```console
$ vex view all kanban --field status
┌───────────────────────────┬─────────────────────────────┐
│ done                      │ todo                        │
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
│ vextype  │ done  │ todo   │ total │
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
