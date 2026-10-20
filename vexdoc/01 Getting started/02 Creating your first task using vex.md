This page walks through the core loop: `init`, `add`, `show`, `set`, `get`, `focus`, `resolve` and `remove`.

## 1. Initialise a project

```console
$ cd my-project
$ vex init
```

Task files go in the folder named by `taskfolder` in `.vex/config.lua`. By default that's the project root (see [[01 Configuring vex (config.lua)]]).

## 2. Add a task

Every word up to the first `--flag` becomes the task's `description`. vex prints the new task's `vexid`, which is also its filename:

```console
$ vex add Make coffee for wife
make-coffee-wife-1
```

`add` also sets your focus to the new task, so the next command applies to it without naming it. Set more fields with flags:

```console
$ vex set --cost 15 --benefit 40 --due "tomorrow 8am"
```

A date or time can be `YYYY-MM-DD HH:MM:SS`, `YYYY-MM-DD`, or a phrase such as `tomorrow 8am`, `friday arvo` or `in 3 days`, read relative to now (see [[01 CLI reference#Interpreting times]]).

## 3. Look at the task

```console
$ vex show
# MAKE-COFFEE-WIFE-1
---
vexid: make-coffee-wife-1
vextype: task
description: Make coffee for wife
benefit: 40
cost: 15
created: 2026-10-20 10:14:24
due: 2026-10-21 08:00:00
modified: 2026-10-20 10:14:24
status: todo
---
```

`show` prints the task's frontmatter and body. With no argument, it uses your current focus. Give it any focus to show several tasks: `vex show all`. See [[02 Frontmatter schema]] for every field.

## 4. Move it forward

```console
$ vex set --status doing
```

`status` follows a state machine: `todo`, then `doing`, then `done`. vex rejects any other move, such as `todo` straight to `done`.

`set` applies to every task in the focus, so one command can update many tasks:

```console
$ vex focus all --filter status:todo
Focusing on 1 vex
$ vex set --status doing
```

## 5. Get data out

```console
$ vex focus all
Focusing on 1 vex
$ vex get --vexid --status --cost
make-coffee-wife-1	doing	15
```

`get` prints one tab-separated line per task in the focus, ready for `cut`, `awk`, `sort` or any other tool that reads TSV.

## 6. Focus on other tasks

A focus is a saved query. Most commands act on it when you don't give them one. Focus on a single task by its `vexid`:

```console
$ vex focus make-coffee-wife-1
Focusing on 1 vex
```

Run `vex focus` with no arguments to print the current focus:

```console
$ vex focus
Current focus on 1 vex
focus	args = 	{
  [1] = "make-coffee-wife-1"
}
```

See [[01 CLI reference#Focuses]] for every way to build one.

## 7. Resolve

```console
$ vex resolve
```

`add`, `set` and `remove` resolve the tasks they change. Run `resolve` yourself after editing a task file in your editor: it validates the file and updates the index.

`vex resolve all` rebuilds the whole index from the files in `taskfolder`. It picks up new files, drops deleted ones, and fails if any task is invalid. That makes it a good `git pre-commit` hook.

## 8. Remove a task

```console
$ vex add Reorder the pantry
reorder-pantry-1
$ vex remove
reorder-pantry-1
```

`remove` deletes every task in the focus, removes links to them from other tasks, and clears your focus. It doesn't ask for confirmation, so check a wide focus with `vex focus` or `vex view tabular` first.

## Next steps

- [[03 Using a recipe to create a sequence of tasks]]
- [[03 Task types (and vexations)]]
- [[04 Views]]
