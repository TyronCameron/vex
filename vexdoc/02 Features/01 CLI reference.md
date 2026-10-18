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
| `vex get [focus] [--fields...]` | Prints one tab-separated line per task. `--select a,b` names the fields as a list. Defaults to `vexid`. |
| `vex set [focus] [--fields...]` | Sets fields on every task in the focus, then resolves them. |
| `vex remove [focus]` | Deletes every task in the focus, removes links to them from other tasks, and clears the focus. |
| `vex focus [focus] [--flags...]` | Builds and saves a focus. With no arguments, prints the saved focus. |
| `vex view [focus] [view] [--flags...]` | Renders the focus with a view. With no arguments, lists the views. See [[04 Views]]. |
| `vex resolve [focus]` | Validates and reindexes the tasks in the focus. `vex resolve all` rebuilds the whole index from disk. |
| `vex recipe [recipe] Description [--fields...]` | Creates tasks from a recipe and focuses on them. With no recipe, lists the recipes. |
| `vex autocomplete shell` | Prints a completion script for `bash`, `zsh`, `fish` or `powershell`. |
| `vex suggest position words...` | Returns completions. The completion script calls it. |
| `vex inline file` | Turns `#vex` tags in a file into tasks and links each tag to its task (see [[#Inline tags]]). |
| `vex open [focus]` | Opens each task in the focus in your editor, at the tag that created it if there is one. |

Every user mistake, such as an unknown focus or an invalid field, fails with a named error and a hint.

## Initialisation

`vex init` creates `.vex` with:

- `config.lua`: the project configuration ([[01 Configuring vex (config.lua)]]).
- `vexdex/`: the index and the saved focus ([[The index]]). Keep it out of git.
- `tasks/`, `recipes/`, `focuses/`, `views/`, `events/`: your extensions (see the Configuration pages).
- `tmp/`: scratch space for atomic writes.

vex uses the nearest `.vex` in the current folder or above it. For a personal task list, create one in your home folder and point its `taskfolder` wherever you like.

## Adding tasks

```txt
vex add Make coffee for wife --cost 5
```

The task file goes in `taskfolder`. Its vexid comes from the description's first sentence. vex lowercases it, drops filler words and `-ly` adverbs, and keeps the main clause ahead of any prepositional phrase, within 32 characters and 6 words. Then it hyphenates the words and appends a counter:

- "Make coffee for wife" → `make-coffee-wife-1`
- "Investigate why the login page is slow on mobile" → `investigate-login-page-slow-1`

`--vextype` picks the task type, and with it the schema the task is validated against (see [[03 Vexations (task types)]]).

## Editing tasks

```txt
vex set make-coffee-wife-1 --status doing --owner alice
```

`set` overwrites each field you give it, then resolves the task. To edit a list field by value, put `--insert` or `--remove` before it:

```txt
vex set plan-trip-1 --insert --children book-flights-1,book-hotel-1
vex set plan-trip-1 --remove --children book-flights-1
```

`--insert` skips values already in the list.

## Focuses

A focus is a lazy, saved query over your tasks. `vex focus` builds one and saves it, and other commands read it back when you don't give them a focus:

```txt
vex focus all --filter status:done
vex get --vexid --description
```

Flags run in order, each one working on the result of the one before. The two commands below build the same focus as `vex focus all --filter status:done --select status,description`:

```txt
vex focus all --filter status:done
vex focus --select status,description
```

### Starting points

| Focus | Tasks |
| --- | --- |
| `all` | Every task. |
| `none` | No tasks. |
| `updated` | Tasks modified since the index was last written. |
| `initial`, `interim`, `final` | Tasks by `phase`: in their type's first status, in between, or in a status with no way out. |
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
| `--between field:low:high` | Tasks with `low <= field <= high`. Leave `low` or `high` empty for an open side: `cost::9`. Dates may be `YYYY-MM-DD`. |
| `--tree field` | The tasks and everything reachable by following `field`, such as `children`. |
| `--reversetree field` | The tasks and everything that reaches them through `field`. |
| `--backlinks` | The tasks that link to these tasks. |
| `--forwardlinks` | The tasks these tasks link to. |
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

### Grouping and ordering

`--groupby` splits a focus into groups. Every later flag then works within each group, so `--orderby` sorts each group and `--rn` numbers each group from 1. This is like SQL's `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`:

```txt
vex focus all --groupby owner --orderby due --rn --select owner,due,rn
vex view tabular
```

Commands and views list the groups one after another. A set operation (`--union`, `--intersect`, `--xor`, `--notin`, `--onlyin`, `--complement`) gathers the groups back into one.

### Interpreting times

`--interpret` before `--filter` or `--between` reads that flag's values as times, relative to now:

```txt
vex focus all --interpret --between "due:now:next tuesday"
vex focus all --interpret --between "due::yesterday"
vex focus all --interpret --filter due:tomorrow
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
- Any other word fails with the `uninterpretable` error.

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

```txt
vex recipe abstract Ship v0.2
```

A recipe creates one or more tasks with fields already filled in. vex ships `abstract`; add your own in `.vex/recipes` ([[04 Configuring recipes]]).

## Inline tags

Write a task where the work is, in any text file:

```txt
-- #vex Handle a missing config file
-- #atom Retry the upload --due 2026-08-01
```

`vex inline <file>` creates a task for each new tag. The tag word sets the type (`#vex`, `#abstract`, `#atom`, `#explore`, `#decision`), the rest of the line works like `vex add`, and an indented tag becomes a child of the tag above it. vex then rewrites each tag to carry the task's vexid, so later runs update the same task, and `vex open` jumps from a task back to its tag.
