## Conventions

`vex <command> [arguments] [--flags]`

- Every word up to the first `--flag` is positional. `add` and `recipe` join them into the description.
- `[focus]` is optional everywhere. Without it, a command uses your saved focus (`prev`). See [[#Focuses]].
- `--field value` sets a field; a `--field` without a value names one.
- Quoting works as in a shell: `--vexbody "two words"` is one value, and `--filter status:"not done"` matches `not done`.
- A comma outside quotes makes a list: `--children a,b` sets two children, and `vex focus a,b` focuses on both tasks. A value containing spaces keeps its commas, and `\,` writes a literal comma.

## Commands

| Command | Description |
| --- | --- |
| `vex help [command]` | Lists every command, or describes one. |
| `vex init` | Creates a `.vex` folder in the current folder. |
| `vex add Description [--fields...]` | Creates and resolves a task, prints its vexid and focuses on it. |
| `vex show [focus]` | Prints each task's frontmatter and body. |
| `vex get [focus] [row_sep] [col_sep] [--fields...]` | Prints one tab-separated line per task. `--select a,b` names the fields as a list. Defaults to `vexid`. A row separator and a column separator replace the newline and tab (see [[01 CLI reference#Feeding a focus into a list field]]). |
| `vex set [focus] [--fields...]` | Sets fields on every task in the focus, then resolves them. |
| `vex remove [focus]` | Deletes every task in the focus, removes links to them from other tasks, and clears the focus. |
| `vex focus [focus] [--flags...]` | Builds and saves a focus. With no arguments, prints the saved focus. |
| `vex view [focus] [view] [--flags...]` | Renders the focus with a view. With no arguments, lists the views. See [[04 Views]]. |
| `vex resolve [focus]` | Validates and reindexes the tasks in the focus. `vex resolve all` rebuilds the whole index from disk. |
| `vex recipe [recipe] Description [--fields...]` | Creates tasks from a recipe and focuses on them. With no recipe, lists the recipes. |
| `vex autocomplete shell` | Prints a completion script for `bash`, `zsh`, `fish` or `powershell`. |
| `vex suggest position words...` | Returns completions. The completion script calls it. |

Every user mistake, such as an unknown focus or an invalid field, fails with a named error and a hint.

## Initialisation

`vex init` creates `.vex` with:

- `config.lua`: the project configuration ([[01 Configuring vex (config.lua)]]).
- `vexdex/`: the index and the saved focus ([[The index]]). Keep it out of git.
- `tasks/`, `recipes/`, `focuses/`, `views/`, `events/`: your extensions (see the Configuration pages).
- `tmp/`: scratch space for atomic writes.

vex uses the nearest `.vex` in the current folder or above it. For a personal task list, create one in your home folder and point its `taskfolder` wherever you like.

## Adding tasks

```console
$ vex add Make coffee for wife --cost 5
```

The task file goes in `taskfolder`. Its vexid comes from the description's first sentence. vex lowercases it, drops filler words and `-ly` adverbs, and keeps the main clause ahead of any prepositional phrase, within 32 characters and 6 words. Then it hyphenates the words and appends a counter:

- "Make coffee for wife" → `make-coffee-wife-1`
- "Investigate why the login page is slow on mobile" → `investigate-login-page-slow-1`

`--vextype` picks the task type, and with it the schema the task is validated against (see [[03 Task types (and vexations)]]).

## Editing tasks

```console
$ vex set make-coffee-wife-1 --status done --owner alice
```

`set` overwrites each field you give it, then resolves the task. To edit a list field by value, put `--insert` or `--remove` before it:

```console
$ vex set plan-trip-1 --insert --children book-flights-1,book-hotel-1
$ vex set plan-trip-1 --remove --children book-flights-1
```

`--insert` skips values already in the list.

## Focuses

A focus is a lazy, saved query over your tasks. `vex focus` builds and saves one, and other commands read it back when you give them none. [[05 Getting into focus]] has the details and worked examples:

```console
$ vex focus all --filter status:done
$ vex get --vexid --description
```

Flags run in order, each on the result of the one before. These two commands build the same focus as `vex focus all --filter status:done --select status,description`:

```console
$ vex focus all --filter status:done
$ vex focus --select status,description
```

### Feeding a focus into a list field

`vex get` prints a focus in whatever shape you ask for, so the shell can hand the saved focus to any list field. Put a row separator after the focus and `vex get prev ,` prints the vexids as one comma list. Combined with the shell's `$(...)`, that links a whole query result to a task:

```console
$ vex focus my-abstract-1 --tree children --filter vextype:atom
$ vex set my-final-task-1 --dependencies $(vex get prev ,)
```

`--insert` and `--remove` work with it as they do with typed values, so `vex set my-final-task-1 --insert --dependencies $(vex get prev ,)` adds the focus to the dependencies already there. The vexids are a snapshot taken when the command runs: the task stays linked to those tasks, not to the focus. Give `set` its target explicitly, because `prev` would otherwise be both source and target.

The first word after the focus is the row separator and the second is the column separator. They default to a newline and a tab. `\n`, `\t` and `\r` are read as the characters they name, and `""` joins with nothing:

```console
$ vex get prev ,
$ vex get prev "\n" " | " --vexid --description
$ vex get prev ""
```

A list field's own values are joined with commas inside a cell, so a comma column separator is ambiguous for those.

### Starting points

| Focus | Tasks |
| --- | --- |
| `all` | Every task. |
| `none` | No tasks. |
| `updated` | Tasks modified since the index was last written. |
| `initial`, `interim`, `final` | Tasks by `phase`: in their type's first status, in between, or in a status with no way out. |
| `ready` | Tasks that can be started now: not `final`, with no `blockers`. |
| `prev` | The saved focus. The default wherever a focus is optional. |
| a vexid | That task. |
| a path containing `/` | The task file, or every task file in the folder. |
| `a,b,...` | The union of each. |

Your own named focuses go in `.vex/focuses` ([[05 Configuring focuses]]).

### Flags

Values are separated by `:`.

| Flag | Keeps |
| --- | --- |
| `--select field,field` | Only those fields, plus `vexid`. Transients are included once selected. |
| `--filter field:value` | Tasks whose `field` equals `value`. |
| `--fuzzy field:value[:n]` | Tasks whose `field` contains `value` within `n` edits (default 3). |
| `--nil field` | Tasks that hold no value for `field`, transients included: `--nil due`. |
| `--between field:low:high` | Tasks with `low <= field <= high`. Leave `low` or `high` empty for an open side: `cost::9`. Dates may be `YYYY-MM-DD`. |
| `--step field[:field...]` | The tasks one hop along `field`, such as `children`, `forwardlinks` or `backlinks`. |
| `--tree field[:field...]` | The tasks and everything reachable by following `field`, hop after hop. |
| `--reversetree field[:field...]` | The tasks and everything that reaches them through `field`. |
| `--complement` | Every task not in the focus. |
| `--union focus` | Tasks in either focus. |
| `--intersect focus` | Tasks in both. |
| `--xor focus` | Tasks in exactly one. |
| `--notin focus` | Tasks in this focus but not the other. |
| `--onlyin focus` | Tasks in the other focus but not this one. |
| `--interpret` | Reads the next flag's values as natural-language times (see below). |
| `--orderby field[:desc]:field...` | The tasks sorted by each field in turn, ascending unless followed by `desc`. Ties keep their order, and missing values sort last. |
| `--groupby field[:desc]:field...` | The tasks in groups that share those fields' values, ordered as `--orderby` would order them. |
| `--rn` | Each task numbered from 1 within its group, in the field `rn`. |
| `--first n` | Only the first `n` tasks, in the order so far (within each group, after `--groupby`). Use it after `--orderby`. |
| `--last n` | Only the last `n` tasks, in the order so far. Does not reverse them. |

`n` is a whole number above zero. A number larger than the focus keeps everything:

```console
$ vex focus all --orderby created:desc --first 10
$ vex focus all --orderby created:desc --last 10
```

`backlinks` and `forwardlinks` are transients (the tasks linking to a task, and the tasks it links to), so `--tree backlinks` collects everything that depends on a task, directly or not.

### Grouping and ordering

`--groupby` splits a focus into groups. Every later flag then works within each group, so `--orderby` sorts each group and `--rn` numbers each group from 1. This is like SQL's `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`:

```console
$ vex focus all --groupby owner --orderby due --rn --select owner,due,rn
$ vex view tabular
```

Commands and views list the groups one after another, and the `tabular` view gives each group a subheader. The `tabular` view takes the same flags without saving the focus, so `vex view all tabular --groupby owner --orderby due` shows the groups in one command. A set operation (`--union`, `--intersect`, `--xor`, `--notin`, `--onlyin`, `--complement`) gathers the groups back into one.

### Interpreting times

Dates and times can be written as phrases, read relative to now: in `add` and `set` (`--due "friday arvo"`), in a hand-edited task file, and in focus values. `--interpret` before `--filter` or `--between` reads that flag's values through each field's interpret iso:

```console
$ vex focus all --interpret --between due:now:"next tuesday"
$ vex focus all --interpret --between due::yesterday
$ vex focus all --interpret --filter due:tomorrow
```

A saved focus is read again each time it is used, so "next tuesday" always means the coming Tuesday. Phrases combine a day, a time of day and an offset, in any order:

| Kind | Examples |
| --- | --- |
| Now and nearby days | `now`, `today`, `tonight`, `tomorrow`, `yesterday` |
| Weekdays | `wed`, `friday`, `next tuesday`, `last monday`, `weekend` |
| Periods | `next week`, `last month`, `next year`, `this year`, `next fall`, `winter` |
| Dates | `26 July`, `July 26th`, `the 26th of December 2026`, `the 3rd`, `2026-07-26` |
| Times of day | `first light`, `dawn`, `morning`, `morn`, `noon`, `arvo`, `afternoon`, `end of day`, `eve`, `dusk`, `night`, `midnight` |
| Clock times | `5pm`, `3:30pm`, `15:00`, `at 9` |
| Offsets | `fifteen minutes`, `in 3 days`, `half day`, `an hour and a half`, `2 weeks ago` |

- A weekday or date means its next occurrence. A date with no year falls on or after today; a weekday falls after today.
- A time of day on its own means the next time it comes round.
- A day without a time means its first moment, 00:00.
- Weeks start on Monday, and seasons start on the first of March, June, September and December.
- Joining words such as `by`, `before`, `on`, `at`, `in`, `the`, `until` and `due` are skipped, so `by 26 July` and `before 26 July` mean 26 July.
- Any other word fails with an error naming the unknown words and giving examples of phrases vex reads.

## Views

`vex view <focus> <view>` renders a focus. See [[04 Views]] for the built-in views and [[02 Configuring views]] for your own.

## Resolution

Resolution keeps every task valid. `add`, `set`, `remove` and `recipe` resolve the tasks they touch, and `vex resolve` resolves a focus on demand. For each task, vex runs the schema of its type and of every type it extends:

1. **Normalise.** Fill defaults (`vextype`, `status`, `created`, `modified`) and convert values: `"15"` to `15`, `"2026-08-01 09:00:00"` to a timestamp, `[[vexid]]` to `vexid`.
2. **Validate.** Check every field against its schema. Links must point at existing tasks, `status` must follow its state machine, `owner` must be a configured user, dependencies must not form a cycle, and a child can have only one parent.
3. **Derive.** Compute derived fields and record the task's links.
4. **Index.** Store the task in `.vex/vexdex` and write its file, formatted for reading.

`vex resolve all` first rebuilds the index from every file under `taskfolder`, so it finds files created, edited or deleted outside vex. A failure exits non-zero with a named error, which makes `vex resolve all` a useful `git pre-commit` hook.

## Recipes

```console
$ vex recipe abstract Ship v0.2
```

A recipe creates one or more tasks with fields already filled in. vex ships `abstract`; add your own in `.vex/recipes` ([[04 Configuring recipes]]).
