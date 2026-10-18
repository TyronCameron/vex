A view renders the tasks in a focus:

```txt
vex view [focus] [view]
```

With no arguments, `vex view` lists the views. With one argument, it is the view, rendering the saved focus. Views show the fields each task stores. A focus built with `--select` shows only the selected fields, transients included.

## `tabular`

A table of every field except the body, formatted for reading.

```txt
vexid                 vextype   status
make-coffee-wife-1    task      doing
ship-beta-1           abstract  todo
```

## `csv`

The same data as comma-separated values, quoted where needed, for spreadsheets, `duckdb` or scripts:

```txt
vex view all csv > tasks.csv
```

## `json`

The tasks as a JSON array.

## `kanban`

One column per value of a field, `status` by default:

```txt
vex view all kanban --field status
```

```txt
┌────────────────────┬────────────────────┐
│ todo               │ doing              │
├────────────────────┼────────────────────┤
│ ship-beta-1        │ make-coffee-wife-1 │
└────────────────────┴────────────────────┘
```

## `overview`

Statistics for the focus:

- **Scope**: the share of each `vextype` in each `status`, with totals.
- **Quality**: the share of tasks with an empty body.
- **Structure**: the share of tasks with no parent and with no dependencies.
- **Movement**: the earliest `created` and the latest `modified` date.

## `singular`

Everything about one task. The focus must hold exactly one task.

```txt
vex view make-coffee-wife-1 singular
```

The view shows the task's type, status and dates, then four sections: its parents (from the root down), its children, the tasks it depends on, and the tasks that depend on it.

Add your own views in `.vex/views` ([[02 Configuring views]]).
