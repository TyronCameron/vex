# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

vex is **the embeddable, local-first, markdown-based task system** — a single LuaJIT CLI binary (`src/vex`). Every task is a plain-text markdown file with YAML frontmatter; every project keeps its own `.vex` folder (like a `.git` folder) holding config, a binary index, and the saved "focus" (current query). There is no server, no daemon, no account.

The project is early (`v0.1.0`), single-developer, and **dogfoods itself**: this repo's own backlog lives under `vexdoc/vex/*.md` and is tracked via `vex` (see `.vex/config.lua`'s `taskfolder = "vexdoc/vex"`). The `vexdoc/` folder is an Obsidian vault that is both the project wiki *and* the live task database — don't treat `vexdoc/vex/*.md` files as throwaway docs, they are real task state with a schema.

## Commands

```txt
./src/vex <verb> [args]          # run the CLI directly (chmod +x src/vex first if needed)
just test                        # test-unit + test-e2e
just test-unit                   # unit tests, in an isolated tmp .vex dir (see below)
just test-e2e                    # busted --run=e2e (black-box, shells out to src/vex)
```

There is no build step (LuaJIT runs `.lua` sources directly) and no linter configured.

`lux.toml`'s `[run] args = ["src/main.lua"]` is **stale** — that file doesn't exist. The real entrypoint is `src/vex.lua`, launched through the `src/vex` shell wrapper (`src/vex.bat` on Windows), which resolves its own directory and sets `package.path`/`package.cpath` before `require 'vex'`. Use `./src/vex`, not `lux run`.

### Running a single test

Unit tests (`test/unit/**/*_spec.lua`, busted) must run with a **fresh, isolated `.vex` directory** as cwd — never run busted directly from the repo root, since that would exercise this repo's own dogfooded task data. Follow the pattern in `justfile`'s `test-unit`:

```bash
repo="$(pwd)"
tmp=$(mktemp -d)
(cd "$tmp" && "$repo/src/vex" init)
(cd "$tmp" && busted --helper="$repo/test/unit/load.lua" --config-file="$repo/.busted" "$repo/test/unit/core/task_spec.lua")
```

Swap the last path for any single spec file, or add busted's `--filter=<pattern>` to match specific `it(...)` blocks.

e2e tests (`test/e2e/*_spec.lua`) are black-box: they never `require` core/lib modules, only shell out to the compiled `src/vex` binary via `test/e2e/helper.lua`'s `run_vex(cwd, args)`, each in its own `mktemp -d`. Run one file with `busted --run=e2e test/e2e/lifecycle_spec.lua`.

`.busted` defines three profiles: `default` (unit), `apiUnit` (tag-filtered subset), `e2e`.

## Architecture

### Entry point and plugin bootstrap (`src/vex.lua`)

Registers seven plugin **enums** (named slots with exactly one active implementation), loads every file under `src/plugin/`, then hands off to `lib.cli`. Plugin loading is skipped when the verb is `init`, otherwise everything (including `core.vexdex`, whose module load throws if no `.vex` exists) gets eagerly required — this is why `init`'s own verb body has to run before any plugin touches `vexdex`.

### The plugin system (`src/lib/plugin.lua`)

Everything swappable in vex — id generation, file path layout, serialization format, sort order — goes through one mechanism:
- `plugin:add(name)` / `plugin:addall(dir)` — register standalone plugins (e.g. `src/plugin/vexcomplete.lua`, the only real one today).
- `plugin:addenum(name, members)` — register a named set with one active member.
- `plugin:get(name)` — resolve to a module, `pcall`-requiring `plugin.<name>` first and falling back to `default.<name>` if that plugin isn't overridden. This is why `src/default/*.lua` holds the actual reference implementations for every slot (`tagger`, `taskpath`, `taskformat`, `dataformat`, `sortdata`, `frontmatter`, `body`) without a project needing to override anything.

`Plugin:select`/`enable`/`disable`/`reload` exist for runtime switching but nothing in the CLI currently exposes them.

### Data flow: add → resolve → write

1. **`TaskManager:add`** (`src/core/task.lua`) generates a `vexid` via the active `tagger` plugin (`default.canonicalvexid`: lowercase, strip filler words, keep first 4 remaining words, hyphenate, append a uniqueness counter — e.g. "Make coffee for wife" → `make-coffee-wife-1`) and holds the task in memory only.
2. **`TaskManager:resolve`** walks the task's `vextype` parent chain (registered in `src/core/taskdefinitions.lua`) and runs each ancestor schema's `prevalidate` (normalise/derive defaults) → `validate` → `postvalidate` (derive computed fields) in order, via `src/lib/schema.lua`. Throws a named CLI error (`resolution-failed-*`) on any failure.
3. **`TaskManager:write`** formats the task (applying any schema `iso`s, e.g. epoch timestamp ↔ `YYYY-MM-DD HH:MM:SS`), writes it through the active `taskformat` plugin, and indexes it. Writes go through `VexDex:atomic` (write to `.vex/tmp/<random>.txt`, then `os.rename`) to avoid partial writes.

`vex add`/`vex set` (in `src/core/verbs.lua`) call resolve+write automatically; `vex resolve all` does a full filesystem reindex first (`TaskManager:reindexall`, walks `taskfolder` from disk).

### Schema system (`src/lib/schema.lua`)

A small validation/transformation DSL, not a data-modeling library you'd recognize from elsewhere. Schemas are registered once by name (`Schema.register 'str' { validate = ... }`) and instantiated with a specification (`schema.atleast { field = schema.str, ... }`). Each schema type can define `prevalidate`/`validate`/`postvalidate`/`iterate`/`isos`. Composable primitives: `atleast`/`exactly`/`atmost` (table shape), `maybe`/`default`/`derive` (optionality), `vec` (arrays), `any`/`all`/`none` (union-style combinators), `formatted`/`serialized` (apply an iso before validating). `iterate` is what lets a container schema recurse into children — see `Context:descend` for how the validation path/type-stack is tracked for error messages.

Task type schemas live in `src/core/taskdefinitions.lua`: base `task` (has `vexid`, `description`, `vextype`, `created`, `modified`, `status`, optional `due`/`cost`/`benefit`/`dependencies`/`vexbody`), extended by `abstract` (adds `children`), `decision` (adds `options`+`decision`), `exploration` and `atom`. Custom types would extend these via `task:task 'name':extends 'parent' { schema = ... }`, though nothing yet loads user-defined types from a project's `.vex/tasks/` folder.

### Focus: the query layer (`src/core/focus.lua`)

A `Focus` is a lazy, composable, **persisted** query over the task index (`.vex/vexdex/focus.bin`). Every operation (`select`, `filter`, `fuzzy`, `between`, `tree`, `reversetree`, set ops) returns a new `Focus` and records itself in `self.operations`, so a focus can be serialized/deserialized and replayed. Named focuses: `all`, `none`, `updated`, `prev` (the default when a verb's `[focus]` arg is omitted), a bare `vexid`, or a file/folder path. `vex focus <name> [--flags]` builds and saves one; most other verbs (`show`, `get`, `set`, `view`, `resolve`, `remove`) read the saved focus back when no argument is given.

Known-broken: the binary set-op flags (`--union`/`--intersect`/`--xor`/`--notin`/`--onlyin`) crash through the CLI because `Focus.parse` passes the flag's raw string value straight into e.g. `Focus:union(focus)`, which expects a `Focus` object, not a name to resolve.

### Views (`src/core/view.lua`)

Pluggable display formats over a focus's task list: `csv`, `tabular`, `json`, `kanban`, `overview` (scope/quality/structure/movement stats), `singular` (tree + DAG diagram for one task). `vex view [focus] [view]`.

### CLI framework (`src/lib/cli.lua`)

A from-scratch verb/error registry, not a wrapper around an existing arg-parsing library:
- `cli:verb "name" { fn, doc = ..., args = ..., example = ... }` registers a command.
- `cli:error "name" { fn, hint = ... }` registers a named error type; `cli:throw('name', ...)` prints the formatted message + hint to stderr and `os.exit(1)`. All of vex's user-facing errors go through this (see `src/core/errors.lua` for the full catalog) — prefer adding a new named error over an ad hoc `assert`/`error` when something is a user-facing failure rather than a bug.
- Argument parsing (`parse_args`) splits `"verb --flag value positional"` into a mixed array/hash `Arguments` table; `--flag` with no following value (or one starting with `--`) becomes a boolean-ish presence flag. **Flag values can't contain spaces** — the CLI reassembles `arg` with `table.concat(arg, " ")` and re-splits on whitespace, so shell-quoted multi-word flag values get torn apart. This is why `due` uses `T` as a date/time separator instead of a space.
- `cli:call` wraps every verb body in `xpcall`, converting any Lua error into a `bug` CLI error with a traceback — a verb function crashing doesn't need its own top-level pcall.

### Storage (`.vex/` and `src/core/vexdex.lua`)

`vex init` creates: `vexdex/` (index + focus, real), `config.lua` (the one file actually read every run, real), and `tasks/`, `recipes/`, `focuses/`, `views/`, `events/` (scaffolded extension points — folders exist, nothing reads them yet), plus `tmp/` for atomic writes. The index and focus are each persisted twice per write: a `binser`-serialized `.bin` (what's actually read back) and a human-readable `pretty`-printed `.lua` mirror (debugging aid only, never read). `VexDex.new()` walks up from cwd looking for `.vex` and throws `not-vexed` if none is found — this happens at **module load time**, which is why plugin loading is skipped during `init` (see above).

### Config (`src/core/config.lua` / `src/lib/config.lua`)

`config.lua`'s `Config:loadall()` `dofile`s each registered path (currently just `.vex/config.lua`) and merges the returned table into `properties`, later paths overwriting earlier ones — there's no inheritance chain wired up yet despite that being a stated design goal. Access via metatable fallthrough (`config.taskfolder`, etc.), not a getter method.

### Recipes (`src/core/recipe.lua`)

A recipe is a named shortcut producing a task with some fields pre-filled (`Recipe:recipe 'name' { add = function(task, taskproperties) ... end }`). Only `abstract` ships (`src/core/taskdefinitions.lua`), which forces `vextype = 'abstract'`. `Recipe:add` only resolves/writes the **single** vexid the recipe's `add` function returns — a recipe that calls `task:add` multiple times to create several tasks only persists the last one to disk (see `vexdoc/Home.md`'s recipe example for the full explanation). Project-specific recipes from `.vex/recipes/` aren't loaded yet.

### Singletons

`core.task`, `core.vexdex`, `core.focus`, `core.view`, `core.recipe`, `core.config`, `lib.cli`, `lib.plugin` are all modules that `require`-cache a single constructed instance (`return TaskManager.new()` etc. at end of file) rather than exposing a class you instantiate yourself. Requiring the module *is* getting the instance.

### Stub libraries

`src/lib/tree.lua`, `dag.lua`, `event.lua`, and `state.lua` are currently **empty files** (0 bytes) — reserved names from the original code plan (see `vexdoc/Vex.md`) that nothing requires yet. Don't assume they contain anything.

## Conventions

- Metatable-based "OO": `Module.new()` + `Module.__index = Module`, methods as `function Module:method(...)`.
- Minimal comments; where present they explain a non-obvious *why* (see e.g. the workarounds documented in `test/e2e/helper.lua`), not what the code does.
- Tests mirror `src/`'s directory structure under `test/unit/` (`test/unit/core/task_spec.lua` tests `src/core/task.lua`, etc.).
- New CLI verbs go in `src/core/verbs.lua` (or a plugin file) using `cli:verb "name" { ... }`; new user-facing errors go in `src/core/errors.lua` using `cli:error "name" { ... }`.

## Working practices

### 1. Think before coding

Don't assume. Don't hide confusion. Surface tradeoffs. Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity first

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical changes

Touch only what you must. Clean up only your own mess. When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-driven execution

Define success criteria. Loop until verified. Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```txt
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

These guidelines are working if: fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
