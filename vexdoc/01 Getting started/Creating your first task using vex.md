This walks through the core loop — `init`, `add`, `show`, `set`, `resolve` — using the default pluggable behaviour vex ships with. See [[Plugin architecture]] if you want to know what "default" means here. Every command below was actually run to confirm it works as described.

## 1. Initialize a project

```txt
cd my-project
vex init
```

This creates a `.vex` folder. Nothing else needs to exist yet — vex will create task files under the folder named by `taskfolder` in `.vex/config.lua` (see [[Configuring vex (config.lua)]]), which defaults to the project root itself.

> [!WARNING] Confirmed broken on a genuinely fresh project
> `vex init` currently fails outside a directory tree that already has a `.vex` folder somewhere above it — see the warning on [[Installing vex]] before you get stuck here. Once you're inside a working `.vex` tree (this repo's own is one example), everything below works as written.

## 2. Add a task

```txt
vex add Make coffee for wife --owner alice
```

Everything after `add` up to the first `--flag` is joined into the task's `description` — `add` doesn't care how many words you use. vex prints the new task's `vexid` (its generated id/filename — the tagger keeps up to the first 4 non-filler words and always appends a counter, e.g. `make-coffee-wife-1`) and sets your current focus to it, so the very next command that takes an optional focus argument will default to this task. `owner` isn't schema-validated (see [[Frontmatter schema]]) — it's stored exactly as given, which is exactly what makes the team workflow on [[Home]] work.

> [!WARNING] Skip `--due`, `--cost`, and `--benefit` for now
> These three are confirmed broken today — they fail resolution unconditionally, even with a correctly-formatted value. See the callout on [[Frontmatter schema]].

## 3. Look at what you made

```txt
vex show
```

With no argument, `show` (like most vex commands) operates on your current focus — the task you just added. You'll see the generated frontmatter (`vexid`, `vextype: task`, `status: todo`, `created`/`modified` timestamps, and `owner: alice`) followed by the (currently empty) body. See [[Frontmatter schema]] for what every field means.

## 4. Move it forward

```txt
vex set make-coffee-wife-1 --status doing
```

This is the field resolution actually enforces successfully today: `set` writes the field, then re-resolves the task. See [[Frontmatter schema]]'s callout, though — the *state machine* behind `status` (only `todo → doing → done`, in order) is meant to reject an out-of-order jump (like `todo` straight to `done`) but currently doesn't; it'll just accept whatever you give it.

## 5. Resolve

```txt
vex resolve all
```

`resolve all` reindexes every task from disk and then validates, enriches, and normalises each one — this is the same step that runs automatically after `add` and `set`, but it's worth running by hand after editing task files directly in your editor, since vex won't otherwise notice the change until something asks it to. See the "Resolution" discussion in [[CLI reference]] for the full list of what resolution is meant to check (and the callouts on what currently doesn't work).

## Next steps

- [[Using a recipe to create a sequence of tasks]] to stop repeating yourself.
- [[Task types]] to learn when to reach for `abstract`, `decision`, `exploration`, or `atom` instead of a plain `task`.
- [[Views]] for ways to look at more than one task at a time.
