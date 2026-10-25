# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

vex is **the embeddable, local-first, markdown-based task system** — a single LuaJIT CLI binary (`src/vex`). Every task is a plain-text markdown file with YAML frontmatter; every project keeps its own `.vex` folder (like a `.git` folder) holding config, a binary index, and the saved "focus" (current query). There is no server, no daemon, no account.

The project is early (`v0.0.0`), single-developer, and **dogfoods itself**: this repo's own backlog lives under `vexdoc/vex/*.md` and is tracked via `vex` (see `.vex/config.lua`'s `taskfolder = "vexdoc/vex"`). The `vexdoc/` folder is an Obsidian vault that is both the project wiki *and* the live task database — don't treat `vexdoc/vex/*.md` files as throwaway docs, they are real task state with a schema.

## Commands

```txt
./src/vex <verb> [args]          # run the CLI directly
just test                        # unit + e2e + lint; reports every failing suite
just test-unit [spec...]         # unit tests (all, or the given spec files)
just test-e2e [spec...]          # e2e tests (all, or the given spec files)
just lint                        # luacheck (globals, undefined names, broken loops) + mirror check
just docs [hugo flags]           # build the docs site from vexdoc/ into site/public (needs hugo extended, go and obsidian-export)
```

`.github/workflows/pages.yml` runs `site/build.sh` on every push to `main` and pushes `site/public` to the `gh-pages` branch, which GitHub Pages serves. The script exports `vexdoc/` with `obsidian-export` (turning `[[wikilinks]]` into markdown links; `vexdoc/.export-ignore` leaves the `vex/` backlog out), gives each page a `title`, `weight`, `description` and sidebar `icon`, turns Obsidian callouts into alerts and wraps every table in Lotus Docs' `table-hover` shortcode, then builds it with Hugo and the Lotus Docs theme, pulled in as Hugo modules pinned in `site/go.mod` (`site/hugo.toml`, landing page in `site/data/landing.yaml`). In `vexdoc/`, write shell examples as `console` code blocks: `$ ` starts a command, any other line is its output. `site/layouts/docs/_markup/render-codeblock-console.html` shows the prompt and the output without letting either be selected or copied.

There is no build step: LuaJIT runs the `.lua` sources directly, through the `src/vex` shell wrapper (`src/vex.bat` on Windows). `.busted` runs every test under `luajit`, the runtime vex ships with, and `test/unit/load.lua` refuses to run anywhere else.

## Testing

The tests exist to give fast, trustworthy feedback on any change. Every behaviour change comes with a test at the right layer:

- **Unit tests** (`test/unit/**/*_spec.lua`) cover a module's behaviour through its own API. Every `src/<path>.lua` has a `test/unit/<path>_spec.lua`; `test/unit/mirror.sh` (part of `just lint`) fails when one is missing. Only `src/vex.lua` (covered by e2e), the vendored `src/lib/binser.lua` and `return {}` stubs are exempt. `test/unit/run.sh` runs each spec file in its own fresh `vex init` directory, because `core.vexdex` binds to the cwd's `.vex` when the module loads. Never run busted on unit specs from the repo root: that would read and write this repo's own task data.
- **e2e tests** (`test/e2e/*_spec.lua`) are black-box: they never `require` a vex module, only shell out to `src/vex` in a fresh temp project through `test/e2e/helper.lua` (`helper.project()`, `helper.vex(dir, ...)` which asserts success, `helper.vex_fails(dir, expected_message, ...)`, `helper.frontmatter(path)`, `helper.link(...)`). Anything a user can type belongs here.
  - `smoke_spec.lua` runs every verb, view and focus form over a fixture project with every task type and link. It fails if `vex help` or `vex view` lists something it doesn't exercise, so a new verb or view needs a row there.
  - `storage_spec.lua` guards the files on disk: resolving is idempotent, hand edits are picked up, the index can be rebuilt.
  - `errors_spec.lua` checks that each user mistake gets its named error.
  - `dogfood_spec.lua` resolves a copy of this repo's own backlog, so schema changes that would break real task files fail.

Rules:

- An `Internal error` (the CLI's `bug` error) is always a regression. `helper.run_vex` fails any test whose command prints one.
- Test behaviour, not registration or internals: what a user or caller observes, not that a name exists in a table.
- A test for a known, unfixed bug names its vex task in the test name (e.g. `(fix-between-focus-crashing-1)`) and fails until the bug is fixed. Fix the bug, never weaken or delete the test.
- Every thrown error name must be registered (`test/unit/core/errors_spec.lua` scans `src/` for `:throw('...')`).

## Architecture

### Entry point and plugin bootstrap (`src/vex.lua`)

Registers six plugin **enums** (named slots with exactly one active implementation), loads every file under `src/plugin/`, then hands off to `lib.cli`. Loading `core.vexdex` throws `not-vexed` when no `.vex` exists above the cwd, so `src/vex.lua` only requires `core.verbs` (and with it the vexdex and every plugin) when the verb isn't `init`.

### The plugin system (`src/lib/plugin.lua`)

Everything swappable in vex — id generation, file path layout, serialization format, sort order — goes through one mechanism:
- `plugin:add(name)` / `plugin:addall(dir)` — register standalone plugins (e.g. `src/plugin/vexcomplete.lua`, the only real one today).
- `plugin:addenum(name, members)` — register a named set with one active member.
- `plugin:get(name)` — resolve to a module, `pcall`-requiring `plugin.<name>` first and falling back to `default.<name>` if that plugin isn't overridden. This is why `src/default/*.lua` holds the actual reference implementations for every slot (`tagger`, `taskpath`, `taskformat`, `sortdata`, `frontmatter`, `body`) without a project needing to override anything.

### Data flow: add → resolve → write

1. **`TaskManager:add`** (`src/core/task.lua`) generates a `vexid` via the active `tagger` plugin (`default.canonicalvexid`: first sentence only, lowercase, split on punctuation, drop filler words and `-ly` adverbs, treat prepositions as phrase boundaries, then fill a 32-character / 6-word budget with the main clause before any prepositional phrase, hyphenate, append a uniqueness counter — e.g. "Make coffee for wife" → `make-coffee-wife-1`, "Investigate why the login page is slow on mobile" → `investigate-login-page-slow-1`) and holds the task in memory only.
2. **`TaskManager:resolve`** walks the task's `vextype` parent chain (registered in `src/core/taskdefinitions.lua`) and runs each ancestor schema's `prevalidate` (normalise/derive defaults) → `validate` → `postvalidate` (derive computed fields) in order, via `src/lib/schema.lua`. Throws a named CLI error (`resolution-failed-*`) on any failure. The schema context carries `previous` (the task as last indexed, which `TaskManager:set` leaves untouched; the status state machine checks transitions against it) and `links` (every `vexlink` the task holds, recorded by `vexlink`'s `postvalidate` and stored as backlinks in the vexdex). `TaskManager:remove` cascades through those backlinks (`focus.focus(vexid):backlinks()`): it strips the removed vexid from every property of each linking task, then resolves and rewrites it, so `vexlink` validation can stay strict. Last, resolve **arranges** files (`TaskManager:arrange`): it moves the task's file to where the `taskpath` plugin now puts it (`TaskManager:move`), then does the same for every task it links to (`Focus:forwardlinks`), transitively, and for every task it stopped linking to. So a parent's change moves its children's files, and `vex resolve <vexid>` alone keeps the layout right. `TaskManager:delete` arranges the deleted task's former forwardlinks the same way.
3. **`TaskManager:write`** formats the task with each ancestor schema's `apply('format', ...)` (e.g. epoch timestamp ↔ `YYYY-MM-DD HH:MM:SS`, vexid ↔ `[[vexid]]`), writes it to the file's current location (`TaskManager:getcurrentpath`) through the active `taskformat` plugin, and indexes it. Writes go through `VexDex:atomic` (write to `.vex/tmp/<random>.txt`, then `os.rename`) to avoid partial writes.

`vex add`/`vex set` (in `src/core/verbs.lua`) call resolve+write automatically; `vex resolve all` does a full filesystem reindex first (`TaskManager:reindexall`, walks `taskfolder` from disk).

### Schema system (`src/lib/schema.lua`)

A small validation/transformation DSL, not a data-modeling library you'd recognize from elsewhere. Schemas are registered once by name (`Schema.register 'str' { validate = ... }`) and instantiated with a specification (`schema.atleast { field = schema.str, ... }`). Each schema type can define `prevalidate`/`validate`/`postvalidate`/`iterate`/`isos`. Composable primitives: `atleast`/`exactly`/`atmost` (table shape), `maybe`/`default`/`derive` (optionality), `vec` (arrays), `any`/`all`/`none` (union-style combinators), `formatted`/`serialized` (apply an iso before validating). `iterate` is what lets a container schema recurse into children — see `Context:descend` for how the validation path/type-stack is tracked for error messages. `apply`/`unapply` run an iso through containers the same way (e.g. formatting every element of a `vec`), only ever transform values through an iso, and only format values the iso's owner validates — so anything formatted can always be unformatted again.

Task type schemas live in `src/core/taskdefinitions.lua`: base `task` (has `vexid`, `description`, `vextype`, `created`, `modified`, `status`, optional `due`/`cost`/`benefit`/`dependencies`/`owner`/`vexbody`; `owner` must be one of the config's `taskowners`), extended by `abstract` (adds `children`), `decision` (adds `options`+`decision`), `exploration` and `atom`. A project adds its own types in `.vex/tasks/*.lua` with `task:task 'name':extends 'parent' { schema = ... }`, and transients with `task:transient` (see Transients and Extensions below).

### Focus: the query layer (`src/core/focus.lua`)

A `Focus` is a lazy, composable, **persisted** query over the task index (`.vex/vexdex/focus.bin`). Every operation (`select`, `filter`, `fuzzy`, `between`, `tree`, `reversetree`, `backlinks`, `forwardlinks`, set ops) returns a new `Focus` and records itself in `self.operations`, so a focus can be serialized/deserialized and replayed. Named focuses: `all`, `none`, `updated`, `initial`/`interim`/`final` (a filter on the `phase` transient: where each task's `status` sits in its type's state machine, i.e. the initial state, a sink with no outgoing transitions, or neither), `prev` (the default when a verb's `[focus]` arg is omitted), a bare `vexid`, a file/folder path, or a list of any of these (unioned; the CLI turns `a,b` into one). `vex focus <name> [--flags]` builds and saves one; most other verbs (`show`, `get`, `set`, `view`, `resolve`, `remove`) read the saved focus back when no argument is given.

`schema.formatted` falls back to its schema's `interpret` iso when the format iso can't read a value, so every date field reads phrases on add, set and resolve, and a value neither iso reads raises `{uninterpretable = value, field = path}`, which `Schema:prevalidate` passes through and `TaskManager`'s normalise turns into the `uninterpretable` error. `Focus:interpret()` (`--interpret`) makes the next `filter` or `between` read its values through each field's `interpret` iso before comparing. `date` and `datetime` define that iso with `src/lib/naturaltime.lua`, which reads phrases such as `tomorrow arvo`, `next tuesday` or `3 days ago` relative to the current time, lazily so a saved focus stays relative, and rejects unknown words with `uninterpretable`.

`Focus:groupby(fields...)` is an ordinary operation whose result is a tree of groups, one level per field, each group holding its `field`, `value` and `tasks` (a task list, or the next level's groups). `Focus:chain` runs every operation on each list of tasks in that tree, dropping groups left empty, so `filter`, `orderby(field[, 'desc']...)`, `rn()` (which numbers copies of each group's tasks in `rn`), a further `groupby` and the rest work per group. `Focus:result` returns the tree (`Focus.isgrouped` tells it from a task list), `Focus:groups` its task lists and `Focus:get` flattens it. The `tabular` view applies its flags to the focus in order (`Focus:apply`, without saving it) and puts a subheader above each group. Set operations call `get`, so they gather the groups back into one list. The built-in `urgency` transient is `groupby('owner'):orderby('due'):rn()` over the tasks not in the `final` phase.

### Transients (`src/core/task.lua`)

Fields that are never stored, worked out from the task and the vexdex each time they are read. Unlike a schema's `derive`, nothing reaches the task file or the index. Each one is registered against a task type, apart from that type's schema: `task:transient 'wordcount' { vextype = 'task', definition = function(t) ... end }`. They work through `Task.__index`: reading a field a task doesn't hold falls back to `TaskManager:transientof(vextype, name)`, which walks the type's parent chain like `schemaof`. So stored fields always win, subtypes inherit their ancestors' transients (and can override them), a definition can read other transients, and a transient that reads only the task works from the moment `Task.new` wraps it, before it is resolved or indexed; one that queries the vexdex (like `lineage`) needs the task indexed. Nothing else knows about transients: focuses, `vex get` and views read `task[field]` and get them for free (views show them once `--select`ed; `pairs` never sees them). `TaskManager:format` keeps this working on formatted copies by falling back to the unformatted task. Built in on `task` (`src/core/taskdefinitions.lua`): `wordcount`, `phase`, `lineage` (ancestor vexids through `children`, root first), `path` (where the task file currently is) and `age` (whole days since `created`).

### Views (`src/core/view.lua`)

Pluggable display formats over a focus's task list: `csv`, `tabular`, `json`, `kanban`, `overview` (scope/quality/structure/movement stats), `singular` (tree + DAG diagram for one task). `vex view [focus] [view]`.

### CLI framework (`src/lib/cli.lua`)

A from-scratch verb/error registry, not a wrapper around an existing arg-parsing library:
- `cli:verb "name" { fn, doc = ..., args = ..., example = ... }` registers a command.
- `cli:error "name" { fn, hint = ... }` registers a named error type; `cli:throw('name', ...)` prints the formatted message + hint to stderr and `os.exit(1)`. All of vex's user-facing errors go through this (see `src/core/errors.lua` for the full catalog) — prefer adding a new named error over an ad hoc `assert`/`error` when something is a user-facing failure rather than a bug.
- Arguments parse into a mixed array/hash `Arguments` table (`args:positional()`, `args:flags()`, `args:text()` for prose, `args:modifiers()`); flag entries carry their own metatable, so tell them apart with `cli.isflag(word)`. Shell quoting survives, so `--vexbody "two words"` is one value.
- A comma outside quotes splits a word into a list, for positionals and flag values alike: `--children a,b` gives `{"a", "b"}` and `vex focus a,b` unions both. Any argv word with whitespace was quoted in the shell, so its commas stay literal (`--vexbody "Fixed, then tested"`); `\,` escapes a comma otherwise. A valueless flag right before another flag modifies it: `vex set x --insert --children a,b` / `--remove --children a` edit a list by value (`TaskManager:set`'s `modifiers`).
- `cli:call` wraps every verb body in `xpcall`, converting any Lua error into a `bug` CLI error with a traceback — a verb function crashing doesn't need its own top-level pcall.

### Storage (`.vex/` and `src/core/vexdex.lua`)

`vex init` creates: `vexdex/` (index + focus, real; the index stores plain task data, and `core.task` puts the `Task` metatable back on every entry when it loads), `config.lua` (the one file actually read every run, real), `tasks/`, `recipes/`, `focuses/`, `views/` (extensions, see below), `events/`, plus `tmp/` for atomic writes. The vexdex also keeps `backlinks` (`backlinks[target][source] = true` for every `vexlink` from source to target) and `paths` (where each task file actually is, relative to `taskfolder`), both saved with the index. `TaskManager:getabspath` is where a file *should* be (the `taskpath` plugin); `getcurrentpath` is where it is (`paths`, falling back to `getabspath`). When a task's file isn't at its recorded path (moved by hand, or a stale `paths` after a merge), `TaskManager:read` finds it by filename anywhere under `taskfolder` (`TaskManager:find`), for indexed tasks only, so a new vexid never triggers the walk. The index, backlinks, paths and focus are each persisted twice per write: a `binser`-serialized `.bin` (what's actually read back) and a human-readable `pretty`-printed `.lua` mirror (debugging aid only, never read). `VexDex.new()` walks up from cwd looking for `.vex` when the module loads (see Entry point).

### Config (`src/core/config.lua` / `src/lib/config.lua`)

`Config:loadall()` `dofile`s each registered path (currently just `.vex/config.lua`) and merges the returned tables, later paths overwriting earlier ones. Read values as fields: `config.taskfolder`, `config.taskowners`, `config.default.tasktype` (the `vextype` `TaskManager:add` gives a task without one), `config.paths`.

`paths.groupby` (read by `src/default/grouppath.lua`, the only `taskpath` member) is a list of field names, transients included, that nests task files in folders, e.g. `paths = { groupby = {'lineage', 'status'} }` puts a task at `<root>/<parent>/<status>/<vexid>.md`. A list value nests one folder per element; unset values and empty lists are skipped; each value is kept to a single folder name (`/`, `\`, `:` and the like become `-`). Without `paths.groupby`, files sit flat at `<vexid>.md`. Anything but a list of strings throws `bad-groupby`.

### Extensions (`src/core/extensions.lua`)

Required at the end of `core.verbs`, once every manager exists. It runs each `.lua` file in the project's `.vex/tasks/`, `.vex/recipes/`, `.vex/focuses/`, `.vex/views/` then `.vex/events/` (each sorted by path) through `loadfile` + `setfenv`, in an environment that exposes `task`, `recipe`, `focus` (the `Focus` class: `focus.register_focus(name, get)`), `view`, `schema` and `event` on top of `_G`, so a file registers things directly (`task:task 'bug':extends 'task' { ... }`) without any `require`. A file that fails to load throws `bad-extension`.

### Events (`src/lib/event.lua`)

A singleton event manager: `event:register(event, handle, fn)` (or `event:on 'name' (fn)`), `event:remove(event, handle)`, `event:trigger(event, ...)`. Handlers run in registration order, then every `*` handler with `(event, ...)`. A failing handler raises a hook error, which `cli:call` turns into the `hook-failed` error, so a hook can stop a command. Every event fires as a `pre-`/`post-` pair: `lib.cli` fires `pre-verb-<verb>` (args) and `post-verb-<verb>` (args, result) around each verb, and each manager fires `<pre|post>-task-<action>`, `focus-write`, `view-display` and `recipe-add` around its public actions (the table with every event's args is in `vexdoc/03 Configuration/06 Configuring event hooks.md`). A new public action on a manager fires its own pair. The vexdex listens on `*`: every event goes to `.vex/vexdex/event-log.txt`, and every `pre-verb-*`'s `args.raw` goes to `verb-log.txt`, which can be replayed to rebuild a project. Both logs are trimmed to `config.loglimit` (default 1000) once per command.

### Recipes (`src/core/recipe.lua`)

A recipe is a named shortcut producing a task with some fields pre-filled (`Recipe:recipe 'name' { add = function(task, taskproperties) ... end }`). Only `abstract` ships (`src/core/taskdefinitions.lua`), which forces `vextype = 'abstract'`. A recipe's `add` returns the list of vexids it added; `Recipe:add` resolves them in that order and focuses on all of them. Projects add their own in `.vex/recipes/*.lua` (see Extensions).

### Singletons

`core.task`, `core.vexdex`, `core.focus`, `core.view`, `core.recipe`, `core.config`, `lib.cli`, `lib.plugin` are all modules that `require`-cache a single constructed instance (`return TaskManager.new()` etc. at end of file) rather than exposing a class you instantiate yourself. Requiring the module *is* getting the instance.

## Where code goes

Putting code in the right place matters more here than anywhere else. Each module owns one concern, and new code uses that module's existing machinery rather than rebuilding a smaller copy of it somewhere else. If the machinery for a common need isn't there or isn't easy to use, say so and ask — don't build it from scratch unless that is the assignment.

- **Getting tasks → `src/core/focus.lua`.** Any "which tasks?" question (by vexid, all of them, children, parents, dependencies, backlinks) is a focus: `focus.focus(name)`, `Focus:tree`, `Focus:backlinks`, etc. Don't loop over `vexdex.index` or call `task:getsingle` to assemble task lists elsewhere; add a focus operation if one is missing.
- **Managing tasks → `src/core/task.lua`.** Adding, setting, removing, resolving, reading and writing tasks, and how changes to one task cascade into others, belong to the `TaskManager`.
- **Validating, normalising, deriving and formatting values → `src/lib/schema.lua`** (generic) and `src/core/taskdefinitions.lua` (vex's task types). Formatting is only ever an iso: whatever is formatted must unformat back. Never format values by hand or by walking a schema from outside `schema.lua`; if the schema machinery can't do something it should, fix `schema.lua` itself.
- **Storage → `src/core/vexdex.lua`.** The index, backlinks and focus, and how they are persisted.
- **Verbs → `src/core/verbs.lua`.** Thin orchestration of the modules above. Verbs don't know about field names, link formats or other details.
- **Display → `src/core/view.lua`.** Views only present tasks they get from a focus.
- **User-facing errors → `src/core/errors.lua`.**
- **Generic helpers → `src/lib/func.lua`** (and the other `src/lib` modules). Check what exists (e.g. `func.ifilter`, `func.ireduce`, `func.imerge`) before writing a loop.

If a new concept appears and it isn't clear which of these it belongs to, stop and discuss it with the user before writing code.

## Conventions

- Metatable-based "OO": `Module.new()` + `Module.__index = Module`, methods as `function Module:method(...)`.
- No explanatory comments. Code should read clearly on its own; the few existing comments (e.g. the workarounds in `test/e2e/helper.lua`) only record a non-obvious *why*.

## Repo preferences

- **Rebuild the index after a checkout.** `.vex/vexdex/` is git-ignored, so run `./src/vex resolve all` after cloning, pulling or switching branches.
- **Track work with vex.** This repo's backlog is vex tasks in `vexdoc/vex/`. When new work or a new bug comes up, raise it with `./src/vex add <description>`, then give the task a body that fully describes it.
- **Organise tasks as a tree of abstracts over atoms.** Every task you create or edit sits under an `abstract` (`--vextype abstract`) that names a category of work in a few words ("Make vex configurable from config", "Fix bugs"); abstracts nest to refine categories downwards, hold only `children`, and have no body. The leaves are `atom`s (`--vextype atom`): one concrete change small enough to finish in a single session, with a body that says what is wrong or missing, where in the code, which doc promises it (link pages as `[[Page name]]` and tasks as `[[vexid]]`), and how to verify it. If an atom needs breaking down, it should have been an abstract: add one and move the pieces under it. Put a new task under the closest existing abstract with `vex set <parent> --insert --children <vexid>` (remove it from its old parent first, since a task has one parent), add a new abstract only for a new category, and link ordering between atoms with `--dependencies`. `paths.groupby` files each task under its status and lineage, so the folders in `vexdoc/vex/` mirror this tree.
- **Close out vex tasks** that a change addresses: move the status through `doing` to `done` with `./src/vex set <vexid> --status ...`. Append to a task's body rather than overwriting it, and only when there is something worth adding: a `done` status already says the task was fixed.
- **Fix docs directly.** When documentation (e.g. this file) is stale or wrong, fix it in place instead of raising a vex task for it.
- **Design before writing code.** Work out which module each piece belongs to (see "Where code goes"), then write the code.
- **Tests come first.** Before starting, make sure the existing tests are enough to validate the change. If they aren't, design and write the tests that need to pass, and see them fail (see "Testing").
- **Run `just test` before calling a change done.** Failures tagged with a vex task are known bugs; anything else is yours.

## Working practices (Andrej Karpathy's guidelines)

These are Andrej Karpathy's guidelines for coding agents. They matter especially here: this is Lua, the public Lua code models learn from is uneven in quality, and this codebase should still read as pristine, simple and easy to follow.

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
