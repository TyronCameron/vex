This walks through the core loop — `init`, `add`, `show`, `remove`, `set`, `get`, `focus`, `resolve` — using the default pluggable behaviour vex ships with. See [[Plugin architecture]] if you want to know what "default" means here.

## 1. Initialize a project

```txt
cd my-project
vex init
```

This creates a `.vex` folder. Nothing else needs to exist yet — vex will create task files under the folder named by `taskfolder` in `.vex/config.lua` (see [[01 Configuring vex (config.lua)]]), which defaults to the project root itself.

> [!WARNING] Broken on a genuinely fresh project
> `vex init` currently fails outside a directory tree that already has a `.vex` folder somewhere above it — see the warning on [[01 Installing vex]] before you get stuck here. Once you're inside a working `.vex` tree (this repo's own is one example), everything below works as written.

## 2. Add a task

```txt
vex add Make coffee for wife --owner alice
```

Everything after `add` up to the first `--flag` is joined into the task's `description` — `add` doesn't care how many words you use. vex prints the new task's `vexid` (its generated id/filename — the tagger keeps up to the first 4 non-filler words and always appends a counter):

```txt
make-coffee-wife-1
```

_**and sets your focus to it**_, so the very next command that takes an optional focus argument will default to this task. `owner` isn't schema-validated (see [[02 Frontmatter schema]]) — it's stored exactly as given, which is exactly what makes the team workflow on the vex [[Home]] page work.

You can set the schema-validated fields the same way:

```txt
vex set --cost 15 --benefit 40 --due 2026-08-01T09:00:00
```

`due` expects `YYYY-MM-DD HH:MM:SS`, but a shell-quoted flag value containing a space gets torn back into two tokens (see the warning on [[01 CLI reference]]) — use `T` as the separator instead of a space, as above, to keep it a single token.

## 3. Look at what you made

```txt
vex show
```

With no argument, `show` (like most vex commands) operates on your current focus — the task you just added. You'll see the generated frontmatter (`vexid`, `vextype: task`, `status: todo`, `created`/`modified` timestamps, and `owner: alice`) followed by the (currently empty) body. See [[02 Frontmatter schema]] for what every field means.

> [!INFO] Showing more than one task at once
> `show` isn't limited to a single task — point it at any focus and it prints every matching task in sequence: `vex show all`.

## 4. Removing a task

```txt
vex add Reorder the pantry
vex remove
```

`remove` (like most vex commands) operates on your current focus, and `add` just set that focus to the task you accidentally created — so a bare `vex remove` deletes it immediately, no further argument needed.

> [!WARNING] Removing in bulk
> `remove` isn't limited to one task either — point it at a focus matching several, and every one of them goes:
> ```txt
> vex add Buy stamps --owner nobody
> vex add Buy envelopes --owner nobody
> vex focus all --filter owner:nobody
> vex remove
> ```
> Both `buy-stamps-1` and `buy-envelopes-1` are gone after that. There's no confirmation prompt, so double-check what a focus actually contains (`vex show` it first) before running `remove` against anything wider than a single task you just created.

## 5. Move it forward

```txt
vex set --status doing
```

This is the field resolution actually enforces successfully today: `set` writes the field, then re-resolves the task. See [[02 Frontmatter schema]]'s callout, though — the *state machine* behind `status` (only `todo → doing → done`, in order) is meant to reject an out-of-order jump (like `todo` straight to `done`) but currently doesn't; it'll just accept whatever you give it.

> [!INFO] Setting fields in bulk
> Point `set` at a focus matching more than one task and every one of them gets the field: `vex focus all --filter owner:alice --filter status:todo` then `vex set --status doing` moves everything Alice still has queued up into "doing" in one call.

## 6. Piping data to an external tool

Add one more task so there's something to pipe out in bulk:

```txt
vex add Draft the release notes --owner alice --status todo
```

```txt
vex focus all
vex get --vexid --owner --status
```

```txt
make-coffee-wife-1	alice	doing
draft-release-notes-1	alice	todo
```

`get` prints one tab-separated line per task in the focus, which is exactly the shape most Unix tools expect — pipe it straight through `cut`, `awk`, `sort`, or anything else that reads TSV:

```txt
vex get --vexid --owner --status | cut -f2
```

```txt
alice
alice
```

Since `get` already runs once per task in the focus, pointing it at a focus matching several tasks pipes all of their rows through in one go — there's no separate "bulk" form needed, it's the same command either way.

## 7. Focusing on other tasks

Everything so far has relied on the *implicit* focus — whatever `add`, `set`, or `focus` last pointed at. You can switch to a specific task explicitly by giving its `vexid`:

```txt
vex focus make-coffee-wife-1
```

Now every following command defaults back to that one task, even if you'd moved on to something else in between. `vex focus` with no arguments at all prints whatever the current focus is, rather than changing it — useful for checking where you are:

```txt
vex focus
```

`prev` — the name for "whatever the last saved focus was" — is the default input to every command that takes an optional `[focus]` argument and doesn't get one, including `vex focus` itself. See [[01 CLI reference#Focuses]] for the full set of ways to build a focus.

## 8. Resolve

```txt
vex resolve
```

If you edit a task in your editor (outside of vex), you should run `resolve` to update `vex`'s index. This ensures the task is searchable from within `vex`.

All tasks that you `add`, `remove`, or `set` are automatically `resolve`d.

> [!INFO] `resolve <focus>` vs. `resolve all`
> `vex resolve` (or `vex resolve <focus>`) re-reads and re-validates each already-tracked task in that focus straight from disk, refreshing the index for those specific tasks — but it only knows about tasks it can already find via a focus, so it won't discover a file you created outside vex, or notice one you deleted by hand.
>
> `vex resolve all` is special: it wipes the index and walks the entire `taskfolder` from scratch, rediscovering everything — new files included, deleted files dropped. That full walk is what makes it a good fit for a periodic integrity check (e.g. a `git pre-commit` hook, as suggested in [[01 CLI reference]]).

See the "Resolution" discussion in [[01 CLI reference]] for the full list of what resolution checks.

## Next steps

- [[03 Using a recipe to create a sequence of tasks]] to stop repeating yourself.
- [[03 Vexations (task types)]] to learn when to reach for `abstract`, `decision`, `exploration`, or `atom` instead of a plain `task`.
- [[04 Views]] for ways to look at more than one task at a time.
