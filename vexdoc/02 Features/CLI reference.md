## Global conventions

In the tables below, `monospaced` values are arguments. Arguments starting with a capital letter (e.g. `Description`) are allowed to be multiple words long — vex joins everything up to the first `--flag` back into one string. A `[focus]` argument is always optional and defaults to `prev` (your last saved focus) when omitted — see [[#Focuses]].

> [!WARNING] Flag values can't contain spaces
> vex reassembles its own argument list with `table.concat(arg, " ")` and re-splits it on whitespace, so a shell-quoted flag value containing a space (e.g. `--field "two words"`) gets torn back into two tokens internally. There's no quoting convention that survives this today.

> [!WARNING] `due`, `cost`, and `benefit` currently can't be set at all
> Confirmed by testing: `--due`, `--cost`, and `--benefit` fail resolution unconditionally today — not a formatting issue, a real bug (`fix-typed-field-cli-input-1` in the project's own vex tasks). `due` fails the same way even if you hand-edit a correctly-formatted value straight into the file. `cost`/`benefit` fail because a CLI flag value is always a string and nothing converts it to a number. Examples below that reference these fields describe the intended behaviour, not something you can rely on today.

## Command list

### Core commands

| **Command**                               | **Description**                                                                                             |
| ------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| vex help \[`verb`]                        | Lists every command; with a `verb`, prints that command's doc, args, and example.                            |
| vex init                                  | Initialises a `.vex` directory in the current directory.                                                     |
| vex show \[`focus`]                       | Prints a task's contents to stdout (highlighted YAML frontmatter, then the markdown body). If the focus resolves to more than one task, prints them all in sequence. |
| vex focus \[`focus`] \[flags...]          | Creates a focus which can be used as a data query against the vex folder. With no args, prints the current focus. More detail below. |
| vex view \[`focus`] \[`view`] \[flags...] | Prints a view of the tasks in a focus. With no args, lists the available views.                              |
| vex resolve \[`focus`]                    | Validates, updates, and normalises fields and tasks. `vex resolve all` also triggers a full reindex first.    |

### Editing tasks

| **Command**                                | **Description**                                                                                                                                          |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vex add `Description` \[--fields...]       | Creates a task with the `Description` provided. Automatically fills out some frontmatter and resolves it. Prints the new `vexid` and sets your focus to it. |
| vex remove \[`focus`]                      | Deletes the tasks in the focus and drops your saved focus. Re-resolves every remaining task afterwards. Not recommended for regular use.                    |
| vex get \[`focus`] \[--fields...]          | Presents the focus as data — one line of tab-separated field values per task. Defaults to just `vexid` if no fields are given.                              |
| vex set \[`focus`] \[--fields...]          | Sets the given fields on every task in the focus, then resolves each one.                                                                                    |
| vex recipe \[`recipe`] `Description` \[--fields...] | Creates a task via a named recipe (see [[#Recipes]]). With no recipe name, lists the recipes available.                                          |

### Shell completion

| **Command**              | **Description**                                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------------------ |
| vex autocomplete `shell`  | Prints a ready-to-install completion snippet for `bash`, `zsh`, `fish`, or `powershell`.                |
| vex suggest `current Command...` | Internal — returns the next-token completion suggestions. This is what the installed snippet calls; you won't normally run it by hand. |

See [[Installing vex]] for how to install the snippet.

### Planned / not yet implemented

Two areas referenced by `config.lua`'s `plugins` table and `vex init`'s scaffolded folders don't have any working commands yet — no plugin file exists for either, so these are documented here as intent, not behaviour:

- **Inline mode** — the idea (from [[Vex]]) is a `#vex Description` tag left inline in any source file that vex would track back to a real task, plus an `open`/`inline` verb pair to jump to a task in your editor or scan a file for tags. Track it via `implement-inline-plugin-1` in the project's own vex tasks.
- **Vexations** — an opinionated bundle of the four [[Task types]] as a plugin layer on top of the base `task` type. Track it via `implement-vexations-plugin-1`.

## Discussion of commands

### Initialisation

Initialising a folder creates a `.vex` directory in the working directory. Inside it, `vex init` creates:

- `vexdex/` — the index and your saved focus (binary + human-readable mirrors — see [[The index]]).
- `config.lua` — the one file vex actually reads on every run (see [[Configuring vex (config.lua)]]).
- `tasks/`, `recipes/`, `focuses/`, `views/`, `events/` — reserved extension points. **None of these are read by vex yet** — see [[Configuring task types]], [[Configuring recipes]], [[Configuring focuses]], [[Configuring views]], and [[Configuring event hooks]] for the current status of each.
- `tmp/` — scratch space vex uses internally for atomic writes (write-then-rename).

If you don't initialise a folder before using vex, vex looks in parent directories for an existing `.vex` folder before giving up — so subdirectories of an initialised project work without re-running `init`.

> [!NOTE] Global vex
> If you wish for a global `.vex` folder, there is nothing stopping you from creating one in your home folder and pointing its `config.lua`'s `taskfolder` at any directory of your choosing.

### Focuses

A focus is a lazy, composable, saveable query over your tasks — the mechanism most other commands operate on. `vex focus` builds one and persists it to `.vex/vexdex/focus.bin`; commands that take an optional `[focus]` argument default to reading that saved focus back (the named focus `prev`) when you don't pass one.

```txt
vex focus all --filter status:done
vex get --vexid --status --description
```

Because the focus is *persisted to disk*, not piped through stdin, this works the same whether you run the two commands separately or connect them with a shell pipe (`vex focus all --filter status:done | vex get ...`) — `vex get` doesn't read stdin at all, it just reads back the focus `vex focus` already saved. Note that `get`'s field selection works differently from `focus`/`view`'s `--select` below: `get` treats every bare `--fieldname` flag you pass as a column to print (one flag per field, no value after it), rather than taking a single flag with a list of names.

They're composable in the sense that you can write either of these with the same meaning:

```txt
vex focus all --filter status:done --select vexid:status:description
```

or, relying on the persisted focus:

```txt
vex focus all --filter status:done
vex focus --select vexid:status:description
```

**Named focuses** (see `src/core/focus.lua`'s `namedfocus.focus()`):
- `all` — every task in the index.
- `none` — the empty set.
- `updated` — tasks whose `modified` timestamp is newer than the index's last write.
- `prev` — your last saved focus. This is the implicit default everywhere a `[focus]` argument is omitted (except for `vex focus` itself, which requires it the first time you use a project).
- Any existing task's `vexid` — resolves to that single task.
- A file or folder path (anything containing a `/`) — resolves to the task(s) at that path.
- A comma-separated list of any of the above — unions them together.

**Flags** (all confirmed against `focus.lua` and the shell-completion suggestions in `vexcomplete.lua`):
- `--select field:field:...` — keeps only those fields (plus `vexid`, which is always included). Fields are colon-separated, matching the same `:`-splitting `--filter`/`--between` use — not commas.
- `--filter field:value` — keeps tasks where `field` equals `value` exactly.
- `--fuzzy field:value` — keeps tasks where `field` is within a small Levenshtein distance of `value` (default distance `3`); add a third colon-separated part, `--fuzzy field:value:n`, to set a custom distance.
- `--between field:begin:end` — keeps tasks where `begin <= field <= end`. Omit `begin` for "less than or equal to `end`"; omit `end` for "greater than or equal to `begin`".
- `--tree field` — walks *forward* along `field` (e.g. `children`), collecting every task reachable by following it.
- `--reversetree field` — walks *backward* along `field` — collects every task that has the current task(s) somewhere in that field (this is how the `singular` view finds an abstract's ancestors, by reverse-treeing over `children`).
- `--complement` — everything *not* in the current focus (confirmed working, takes no value).
- `--union`, `--intersect`, `--xor`, `--notin`, `--onlyin` — meant to combine the current focus with another named focus given as the flag's value. **Confirmed broken via the CLI**: each one crashes with an internal error ("attempt to call method 'get' (a nil value)"), because the flag's raw string value is passed straight through instead of being resolved to an actual focus first. Tracked as `fix-focus-binary-ops-cli-1`.
- `--interpret` — **not implemented**. The intent (per `focus.lua`'s own comment) is to convert natural-language values like `tomorrow` before matching; today it hard-throws "this is a hard feature that I don't know how to do yet." Tracked as `implement-focus-interpret-1`.

All flags run in the order provided, each one narrowing (or transforming) the result of the last.

Mapping and folding are reserved for focuses written in Lua rather than exposed through the CLI.

You'd create new named focuses by adding files to the `focuses` subdirectory of your `.vex` folder — see [[Configuring focuses]] for why that doesn't do anything yet.

### Views

Views are ways to get a high-level look at a set of tasks — tables, CSV, JSON, kanban boards, dependency diagrams, and a stats overview. See [[Views]] for all six built-in views with example output.

Views sit on top of focuses: `vex view <focus> <view>` renders whatever tasks the focus resolves to.

You'd create new views by adding Lua files to the `views` subdirectory of your `.vex` folder — see [[Configuring views]] for why that doesn't do anything yet, including why `config.lua`'s `default.view` key (which looks like it should pick a fallback view) isn't actually read by anything today either.

### Resolution

Resolution is what vex does to check data correctness — it runs automatically after `add` and `set`, and on demand via `vex resolve`. It covers:
- **Data validation.** Fields are checked against their schema — though see the callouts on this page and on [[Frontmatter schema]] for fields where that check is currently confirmed not to work as intended (`status` transitions, `due`, `cost`, `benefit`).
- **Data enrichment.** `created`/`modified` timestamps are stamped in automatically; on `add`, `vextype` defaults to `task` if you didn't set one.
- **Data normalisation.** The intent is that a `due` value like `2026-07-10 09:00:00` gets parsed into an internal epoch timestamp and reformatted back to a readable string for display, with no natural-language parsing (`tomorrow`, `next week`, etc. are not understood, despite a source comment describing that as a future goal). **This step is currently broken** — see the callout near the top of this page; `due` fails validation rather than getting normalised.
- **Link checking.** Fields typed as a `vexlink` (like a decision's `options`) are checked to confirm the referenced `vexid` actually exists.

> [!WARNING] List-typed fields don't survive being written and read back, at all
> `children`, `dependencies`, and `options` are all list-typed. A CLI flag value is always a single string (tracked as `implement-cli-list-fields-1`), so you can't set them that way — but hand-editing the YAML list in the file doesn't work either: confirmed by testing, `src/default/obsidian.lua`'s frontmatter reader parses one `key: value` line at a time and has no support for multi-line YAML lists, so a written array reads back as an empty string. This means an `abstract` task (whose `children` defaults to an empty list) **fails validation the very next time it's resolved from disk** — reproduced with `vex add X --vextype abstract` (works), then `vex resolve all` again (fails on that same task, from then on). `decision` tasks can't be created at all today, since their required `options` field has no default and can never be successfully populated. Tracked as `fix-list-field-roundtrip-1`.

> [!WARNING] Don't wire `vex resolve all` into a commit hook yet
> Given the above, `resolve all` will fail on any project that has ever created an `abstract` task, the moment you run it a second time — so a `git pre-commit`/CI gate built on it would block every commit once that happens. Hold off until `fix-list-field-roundtrip-1` lands.

Resolution rules would be extended per-project via the `tasks` subdirectory of your `.vex` folder — see [[Configuring task types]] for the current (not-yet-implemented) status.

### Adding new tasks

```txt
vex add Make coffee for wife --owner alice
```

This creates a new task file under the `taskfolder` specified in `config.lua` (see [[Configuring vex (config.lua)]]). (Confirmed by testing exactly this command.)

The tagger runs over the description to generate the `vexid` (and filename): it lowercases each word, drops common filler/stop words (articles, conjunctions, auxiliary verbs, etc.), keeps up to the first 4 remaining words in order, joins them with hyphens, and always appends a numeric counter — so "Make coffee for wife" becomes `make-coffee-wife-1` (there's no verb-prioritisation; it's simply the first 4 non-filler words). `vexid`s are unique per project; the counter increments if the same slug comes up again.

Adding a task prints its `vexid` to the screen and sets your focus to it.

Arbitrary fields can be passed to `add`, and vex writes them straight into the task's frontmatter — most, like `owner` above, are just stored as-is with no validation. `due`, `cost`, and `benefit` are meant to be schema-validated real fields (see [[Frontmatter schema]]) but currently fail resolution unconditionally — see the callout near the top of this page.

Passing `--vextype` chooses which task type — and therefore which additional schema — resolution applies to this task. See [[Task types]].

### Editing existing tasks

You can use `set` to edit tasks:

```txt
vex set make-coffee-wife-1 --status doing --owner alice
```

This sets the fields provided, then runs resolution on the task. `status` is *meant* to be checked against the `todo → doing → done` state machine, but that check is currently confirmed not to work (see [[Frontmatter schema]]) — an out-of-order transition is silently accepted rather than rejected. `owner` (not a schema field today) is stored verbatim with no checking, the same as any other arbitrary key.

You can pass arbitrary fields and values through `set` the same way you can through `add`.

### Recipes

A recipe is a named shortcut that creates a task (or, once user-defined recipes exist, potentially several) with some fields already decided. Only one ships today: `abstract`, which forces `vextype` to `abstract`.

```txt
vex recipe abstract Ship v0.2 --status todo
```

You'd add project-specific recipes by creating files in the `recipes` subdirectory of your `.vex` folder — see [[Configuring recipes]] for the current (not-yet-implemented) status, and [[Using a recipe to create a sequence of tasks]] for a walkthrough of what works today.
