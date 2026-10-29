A focus is a saved query over your tasks. Most commands act on a focus, and `vex focus` builds one. This page is a cheatsheet, a reference for the named focuses, the snags to know about, and worked queries. The flags are described in full in [[01 CLI reference#Focuses]].

## Cheatsheet

| Command | Does |
| --- | --- |
| `vex focus <start> [--flags...]` | Builds a focus from a starting point, applies the flags in order and saves it. |
| `vex focus --flags...` | Applies the flags to the saved focus. |
| `vex focus` | Prints the saved focus. |
| `vex get`, `show`, `set`, `resolve`, `remove`, `view` | With no focus given, act on the saved focus. |
| `vex view <start> <view> [--flags...]` | Renders a focus without saving it. |

| Flag | Keeps |
| --- | --- |
| `--filter field:value` | Tasks where `field` equals `value`. |
| `--fuzzy field:value[:n]` | Tasks where `field` contains `value`, give or take `n` typos. |
| `--between field:low:high` | Tasks where `field` is in the range. Either end may be empty. |
| `--select a,b` | Only those fields. |
| `--orderby field[:desc]` | Tasks sorted by those fields. |
| `--groupby field` | Tasks in groups. Later flags work per group. |
| `--rn` | Numbers each group's tasks from 1. |
| `--tree field`, `--reversetree field` | The tasks plus everything below, or above, them through `field`. |
| `--backlinks`, `--forwardlinks` | The tasks that link to these, or that these link to. |
| `--union`, `--intersect`, `--xor`, `--notin`, `--onlyin`, `--complement` | Set operations. |
| `--interpret` | Reads the next flag's values as phrases such as `next tuesday`. |

## Named focuses

A focus starts from one of these:

| Focus | Tasks |
| --- | --- |
| `all` | Every task. |
| `none` | No tasks. |
| `updated` | Tasks modified since the index was last written. |
| `initial` | Tasks in their type's first status (`todo`). |
| `interim` | Tasks in between (`doing`). |
| `final` | Tasks with no way out of their status (`done`). |
| `ready` | Tasks that aren't `final` and have no `blockers`: work you can start now. |
| `prev` | The saved focus. |
| a vexid | That one task. |
| a path containing `/` | The task file there, or every task file in that folder. |
| `a,b` | The union of each. |

`initial`, `interim` and `final` read the `phase` transient ([[06 Status and state machines]]). Your own named focuses go in `.vex/focuses` ([[05 Configuring focuses]]). A name that matches nothing fails with `unknown-focus`.

## How a focus works

### It is a recipe, not a list

A focus saves the steps that build it, not the tasks they found. Every command that uses it runs the steps again, so it always reflects the current tasks:

```console
$ vex focus all --filter status:todo
Focusing on 5 vexes
$ vex set --status doing
$ vex focus
Current focus on 0 vexes
```

The same goes for phrases: a saved `--interpret --between due:now:"next tuesday"` always means the coming Tuesday.

### `prev` is the default

Every `vex focus`, `vex add` and `vex recipe` saves its focus, and every command that takes a `[focus]` uses the saved one when you leave it out. That is why `vex add Fix the leak` followed by `vex set --owner alice` edits the new task. It also means building a focus replaces the one you had. To look at tasks without losing your focus, use `vex view`, which applies its flags for that one command only.

`vex remove` clears the focus. With none saved, a command fails with `no-focus`.

### `vex focus` on its own shows the focus

With no arguments, `vex focus` builds nothing. It prints the saved focus, its size and each step:

```console
$ vex focus
Current focus on 3 vexes
focus	args = 	{
  [1] = "all"
}
filter	args = 	{
  [1] = "status",
  [2] = "todo"
}
```

### Flags build on each other

A flag works on the result of the one before it. Start with a name to begin afresh, or leave the name off to carry on from `prev`:

```console
$ vex focus all --filter status:todo
$ vex focus --select owner,due
```

The second command filters and selects. `vex focus ready --filter owner:alice` starts again from `ready`.

### Smaller snags

- `--select` always keeps `vexid`, and may name transients such as `urgency`. `--filter`, `--between` and `--orderby` accept them too.
- Values are separated by `:`. Quote a value containing spaces or colons: `--filter description:"Fix the leak"`.
- Set operations take a named focus or a vexid, not a query: `--notin final` works, `--notin "all --filter ..."` doesn't. Save the query as a named focus first.
- `--complement` inverts against all tasks, and set operations gather groups back into one list.
- A comma outside quotes is a union: `vex focus a-1,b-1`.
- `--groupby` changes what the flags after it do: `--orderby` sorts inside each group and `--rn` restarts at 1 in each. The `tabular` view draws a heading for each group.

## Example queries

The examples use `vex get` for brevity. Replace it with `vex view tabular --select field,field` for more detail.

### Tasks ready to work on, most urgent first

```console
$ vex focus ready --orderby urgency:due
$ vex view tabular --select owner,due,urgency
```

`ready` drops finished and blocked tasks. `urgency` ranks each owner's open tasks by `due`, so every owner's most urgent task comes first, then everyone's second, and `due` breaks ties.

### Open decisions

```console
$ vex focus all --filter vextype:decision --notin final
Focusing on 1 vex
```

`--notin final` drops decisions already `done`.

### Open explorations

```console
$ vex focus all --filter vextype:exploration --notin final
Focusing on 1 vex
```

### Tasks not under any abstract

```console
$ vex focus all --filter vextype:abstract --tree children --complement
Focusing on 4 vexes
$ vex get
choose-payment-provider-1
old-finished-chore-1
tidy-readme-1
refunds-slow-1
```

`--tree children` gathers every abstract and everything beneath it. `--complement` keeps the rest. Add `--notin final` to leave out finished tasks.

### Each owner's backlog

```console
$ vex view ready tabular --groupby owner --orderby due --select owner,due,status
┌───────────────────────────────┬─────────────────────┬───────┬────────┐
│ vexid                         │ due                 │ owner │ status │
├───────────────────────────────┼─────────────────────┼───────┼────────┤
│ owner: alice                                                         │
│ │ migrate-existing-invoices-1 │ 2026-10-30 00:00:00 │ alice │ todo   │
│ owner: bob                                                           │
│ │ fix-flaky-webhook-retry-1   │ 2026-10-30 00:00:00 │ bob   │ todo   │
│ owner:                                                               │
│ │ ship-billing-rewrite-1      │                     │       │ todo   │
│ │ tidy-readme-1               │                     │       │ todo   │
│ │ refunds-slow-1              │                     │       │ todo   │
│ │ choose-payment-provider-1   │                     │       │ todo   │
└───────────────────────────────┴─────────────────────┴───────┴────────┘
```

Tasks without an owner form their own group. Use `vex focus ready --groupby owner --orderby due --rn` to save it with a position in each backlog.

### Close off an abstract

```console
$ vex focus ship-billing-rewrite-1 --tree children --notin final
Focusing on 4 vexes
$ vex set --status doing
$ vex set --status done
```

`--tree children` takes the abstract and everything under it. Status moves one step at a time ([[06 Status and state machines]]), so `done` needs `doing` first, and `--notin final` leaves out tasks already done, which can't go back to `doing`. The focus is run again for each command, so the second `set` still sees the right tasks.

### Tasks created in the last week

```console
$ vex focus all --interpret --between created:"1 week ago":now
```

`--interpret` reads `1 week ago` and `now` as times. See [[01 CLI reference#Interpreting times]] for every phrase vex understands.
