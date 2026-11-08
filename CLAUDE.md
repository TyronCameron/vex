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
just benchmark                   # time a densely linked project (VEX_BENCHMARK_TASKS tasks, default 1000)
just install [--uninstall]       # install this clone the way a release installs (PREFIX, default ~/.local)
just package <version> [outdir]  # build vex-<version>.tar.gz/.zip + SHA256SUMS into dist/
just docs [hugo flags]           # build the docs site from vexdoc/ into site/public (needs hugo extended, go and obsidian-export)
```

`.github/workflows/pages.yml` runs `site/build.sh` on every push to `main` and pushes `site/public` to the `gh-pages` branch, which GitHub Pages serves. The script exports `vexdoc/` with `obsidian-export` (turning `[[wikilinks]]` into markdown links; `vexdoc/.export-ignore` leaves the `vex/` backlog out), gives each page a `title`, `weight`, `description` and sidebar `icon`, turns Obsidian callouts into alerts and wraps every table in Lotus Docs' `table-hover` shortcode, then builds it with Hugo and the Lotus Docs theme, pulled in as Hugo modules pinned in `site/go.mod` (`site/hugo.toml`, landing page in `site/data/landing.yaml`). In `vexdoc/`, write shell examples as `console` code blocks: `$ ` starts a command, any other line is its output. `site/layouts/docs/_markup/render-codeblock-console.html` shows the prompt and the output without letting either be selected or copied.

`.github/workflows/release.yml` runs `just test`, `scripts/package.sh` and `gh release create` when a `v*` tag is pushed. A release is the platform-neutral `src/` plus `install.sh` / `install.ps1`, which copy it to `$PREFIX/lib/vex` (`%LOCALAPPDATA%\vex` on Windows) and link `bin/vex`; `package.sh` stamps `src/version.lua`, which `vex version` prints. `lux.toml` makes the same sources a LuaRocks/lux package.

There is no build step: LuaJIT runs the `.lua` sources directly, through the `src/vex` shell wrapper (`src/vex.bat` on Windows). `.busted` runs every test under `luajit`, the runtime vex ships with, and `test/unit/load.lua` refuses to run anywhere else.

## Testing

The tests exist to give fast, trustworthy feedback on any change. Every behaviour change comes with a test at the right layer:

- **Unit tests** (`test/unit/**/*_spec.lua`) cover a module's behaviour through its own API. Every `src/<path>.lua` has a `test/unit/<path>_spec.lua`; `test/unit/mirror.sh` (part of `just lint`) fails when one is missing. Only `src/vex.lua` (covered by e2e), the vendored `src/lib/binser.lua` and `return {}` stubs are exempt. `test/unit/run.sh` runs each spec file in its own fresh `vex init` directory, because `core.vexdex` binds to the cwd's `.vex` when the module loads. Never run busted on unit specs from the repo root: that would read and write this repo's own task data.
- **e2e tests** (`test/e2e/*_spec.lua`) are black-box: they never `require` a vex module, only shell out to `src/vex` in a fresh temp project through `test/e2e/helper.lua` (`helper.project()`, `helper.vex(dir, ...)` which asserts success, `helper.vex_fails(dir, expected_message, ...)`, `helper.frontmatter(path)`, `helper.link(...)`). Anything a user can type belongs here.
  - `smoke_spec.lua` runs every verb, view and focus form over a fixture project with every task type and link. It fails if `vex help` or `vex view` lists something it doesn't exercise, so a new verb or view needs a row there.
  - `storage_spec.lua` guards the files on disk: resolving is idempotent, hand edits are picked up by `resolve` and write verbs, the index can be rebuilt, and each verb changes exactly what the CLI reference's columns say (read verbs change nothing).
  - `errors_spec.lua` checks that each user mistake gets its named error.
  - `dogfood_spec.lua` resolves a copy of this repo's own backlog, so schema changes that would break real task files, or rewrite them, fail.
- **Benchmark** (`test/benchmark/run.lua`, `just benchmark`) builds a project through `vex add` (atoms in 10 dependency layers around a hub atom, under 10 levels of abstracts), then times creation, a full `vex resolve all --force`, a `vex set` on the hub, `vex add` and `vex view all csv`. It is black-box like the e2e tests, asserts nothing beyond each command succeeding, and runs as its own CI job on every PR, posting a table that compares it with the base branch as a comment on the PR. `VEX_BENCHMARK_TASKS` sets the size.

Rules:

- An `Internal error` (the CLI's `bug` error) is always a regression. `helper.run_vex` fails any test whose command prints one.
- Test behaviour, not registration or internals: what a user or caller observes, not that a name exists in a table.
- A test for a known, unfixed bug names its vex task in the test name (e.g. `(fix-between-focus-crashing-1)`) and fails until the bug is fixed. Fix the bug, never weaken or delete the test.
- Every thrown error name must be registered (`test/unit/core/errors_spec.lua` scans `src/` for `:throw('...')`).

## Architecture

### Entry point and plugin bootstrap (`src/vex.lua`)

Finds its own install root by searching `package.path` for `lib/plugin.lua`, so it runs the same from a clone, an install or a rock. It puts the global folder (below) and the project's `.vex` on `package.path` (the project's first, so its `plugin/x.lua` wins). It registers six plugin **enums** (named slots with exactly one active implementation), then every file under `src/plugin/`, the global `plugin/` and the project's `.vex/plugin/`. Unless the verb is `init` or `version`, it then requires `core.config` (loading `core.vexdex` throws `not-vexed` when no `.vex` exists above the cwd), applies `config.plugins` with `plugin:configure` (a problem is the `bad-plugin-setting` error), and only then requires `core.verbs` (`core.task` and `core.view` call `plugin:get` as they load, so config must choose the slots first), loads every enabled plugin with `plugin:each`, and requires `core.extensions` last, so extensions can build on the types the `vexations` plugin registers. Then it hands off to `lib.cli`.

### The plugin system (`src/lib/plugin.lua`)

Everything swappable in vex — id generation, file path layout, serialization format, sort order — goes through one mechanism:
- `plugin:add(name)` / `plugin:addall(dir)` — register standalone plugins (`src/plugin/vexcomplete.lua` and `src/plugin/vexations.lua`, the opinionated task types).
- `plugin:addenum(name, members)` — register a named set with one active member. `plugin:select(set, plugin)` makes any registered plugin the active member, including one a project ships in its `plugin/` folder.
- `plugin:configure(settings)` — applies the `plugins` table of the config: `slot = 'plugin'` selects, `plugin = false` / `true` disables / enables a standalone plugin (one that fills a slot can't be disabled). It returns `nil, name, problem` for the first setting it can't apply.
- `plugin:get(name)` — resolve to a module, `pcall`-requiring `plugin.<name>` first and falling back to `default.<name>` if that plugin isn't overridden. This is why `src/default/*.lua` holds the actual reference implementations for every slot (`tagger`, `taskpath`, `taskformat`, `sortdata`, `frontmatter`, `body`) without a project needing to override anything.

### Data flow: add → resolve → write

1. **`TaskManager:add`** (`src/core/task.lua`) generates a `vexid` via the active `tagger` plugin (`default.canonicalvexid`: first sentence only, lowercase, split on punctuation, drop filler words and `-ly` adverbs, treat prepositions as phrase boundaries, then fill a 32-character / 6-word budget with the main clause before any prepositional phrase, hyphenate, append a uniqueness counter — e.g. "Make coffee for wife" → `make-coffee-wife-1`, "Investigate why the login page is slow on mobile" → `investigate-login-page-slow-1`) and holds the task in memory only.
2. **`TaskManager:resolve`** runs the schema of the task's `vextype` (registered in `src/core/taskdefinitions.lua`, and by the `vexations` plugin) once: `prevalidate` (normalise/derive defaults) → `validate` → `postvalidate` (derive computed fields), via `src/lib/schema.lua`. A type's schema is merged with its ancestors' when it is registered (`Schema:merge`, below), so one pass covers every field and a `postvalidate` sees every field normalised and validated. Throws a named CLI error (`resolution-failed-*`) on any failure. The schema context carries `previous` (the task as last indexed, which `TaskManager:set` leaves untouched; the status state machine checks transitions against it) and `links` (every `vexlink` the task holds, recorded by `vexlink`'s `postvalidate` and stored as backlinks in the vexdex). `TaskManager:remove` cascades through those backlinks (`focus.focus(vexid):step('backlinks')`): it strips the removed vexid from every property of each linking task, then resolves it, so `vexlink` validation can stay strict. Resolution also **cascades**: `TaskManager:resolve` is `resolveall` of one task, which resolves each task, and then, for each task that changed, every task linked to it or from it (`step('forwardlinks', 'backlinks')`) and every task it stopped linking to (the previously indexed task's `forwardlinks` that its new links drop), each once per call (`resolveall` queues what `resolvesingle` returns and skips tasks it has resolved), so stored derived fields stay right. A task counts as changed when `VexDex:changed` finds its fingerprint differs from the one kept when it was last indexed, when its file has to move to where the `taskpath` plugin now puts it, or when its file is gone; a task that is unchanged and in place ends the cascade there, so one `add` or `set` costs the tasks it actually affects rather than the whole connected graph. `resolveall` works in memory only: it updates the index and keeps every task it resolved, and whether it changed, in `TaskManager.unwritten`. `TaskManager:writeall` then writes every kept task that changed, moves each one's file to where the `taskpath` plugin now puts it (`TaskManager:move`), and only then removes the files `TaskManager:delete` queued in `TaskManager.deleted`, so a failed write never leaves a link to a removed file. `pop_focus_and_take_edits` (below) takes in hand edits first; each verb that changes tasks then calls `writeall` once, after all of its own resolving, and `writeall` ends by saving the index (`VexDex:writeindex`), the only place it is saved, so a verb that fails partway writes nothing (a write failing partway is not rolled back). So a parent's change moves its children's files, and `vex resolve <vexid>` alone keeps the layout right. `TaskManager:delete` queues the file's removal, drops the task from the index and resolves its former links the same way, and resolving a task whose file is gone or unreadable does the same, leaving any file alone. At the end of `resolvesingle`, `VexDex:changed` compares the task's **fingerprints** (`VexDex:fingerprint`: FNV-1a hashes, `src/lib/hash.lua`, of the task's fields and body, whole and without those in `config.fingerprint.exclude`) with the ones `VexDex:unsafe_add` kept when the task was last indexed (a never-indexed task differs). Only when the second differs is `modified` set to now (`modified` is a `schema.default`, moved outside the schema because its fingerprint covers every field, derived ones included), and only when either differs is the task written. Every file is indexed as read before it is resolved (`reindexall`), so the kept fingerprints match the files. So `modified` moves on a real change, and no file is rewritten, on a no-op `set`, a clean resolve or a rebuilt index.
3. **`TaskManager:write`** formats the task with its type's schema's `apply('format', ...)` (e.g. epoch timestamp ↔ `YYYY-MM-DD HH:MM:SS`, vexid ↔ `[[vexid]]`), renders it to text with the active `taskformat` plugin (`render`; `parse` is the reverse, and `format` highlights a file's text for `vex show`; the plugin only handles text, `lfsext.readfile`/`writefile` do the I/O), writes it to the file's current location (`TaskManager:getcurrentpath`), then has the vexdex stamp the file's mtime (`VexDex:unsafe_stamp`) and indexes it. Writes go through `VexDex:atomic` (write to `.vex/tmp/<random>.txt`, then `os.rename`) to avoid partial writes.

**Changes on disk.** `VexDex:updated` lists every file under `taskfolder` with its mtime in one shell call (`lfsext.mtimes`, hidden entries skipped) and returns the indexed vexids whose file mtime differs from the stamped one (edited, moved, unreadable or gone), and the files no indexed task is at. The `updated` focus is the first of those. Verbs are split into read verbs and write verbs. **Read verbs** (`show`, `get`, `view`, `focus`) never resolve and never write a task file or the index (`focus` with arguments saves only the focus): `get`, `view` and `focus` read the index as last committed (`TaskManager:format(vexid)` formats the indexed task; the index never holds a body, not even in memory: `VexDex:unsafe_add` keeps a body-free copy, and write verbs work on tasks read from their files with `getsingle`) and `warn_stale` in `src/core/verbs.lua` prints a `cli:warn` on stderr while the `updated` focus isn't empty; `show` prints the task file as it is on disk through the `taskformat` plugin's `format`, the only way to see `vexbody`. **Write verbs** take in hand edits with `pop_focus_and_take_edits`, which resolves `focus ∩ updated` (`set`, `remove`, `resolve`), then do their own resolving and commit once with `writeall`. The CLI reference's "What each command touches" table marks what each verb reads and writes, and `storage_spec.lua` checks it. `vex resolve all` is `TaskManager:reindexall`: it reads the unknown files (new or moved by hand, refusing a vexid held by two files) and resolves them with the updated tasks; `--force` clears the index first so every file is read, for config or task type changes. `vex resolve [focus] --force` resolves the whole focus.

### Schema system (`src/lib/schema.lua`)

A small validation/transformation DSL, not a data-modeling library you'd recognize from elsewhere. Schemas are registered once by name (`Schema.register 'str' { validate = ... }`) and instantiated with a specification (`schema.atleast { field = schema.str, ... }`). Each schema type can define `prevalidate`/`validate`/`postvalidate`/`iterate`/`isos`. Composable primitives: `atleast`/`exactly`/`atmost` (table shape), `maybe`/`default`/`derive` (optionality), `vec` (arrays), `any`/`all`/`none` (union-style combinators), `formatted`/`serialized` (apply an iso before validating). `iterate` is what lets a container schema recurse into children — see `Context:descend` for how the validation path/type-stack is tracked for error messages. `Schema:merge(other)` returns a new schema of the same type (merging two types is an error) whose specification is `func.merge` of both, `other`'s keys winning, or `other`'s when either isn't a table. `apply`/`unapply` run an iso through containers the same way (e.g. formatting every element of a `vec`), only ever transform values through an iso, and only format values the iso's owner validates — so anything formatted can always be unformatted again.

The base task types live in `src/core/taskdefinitions.lua` (`basetask` and `task`). The reusable schema objects live in `src/core/schemaext.lua`, registered by name like any other schema (`schema.status`, `schema.dependencies`, `schema.children`, `schema.vexlink`, the tag schemas, and the constraints `acyclic`, `childless`, `dueinorder`, `notself`, `singleparent`): `Schema.register` also takes a prebuilt schema, so a composite like `schema.dependencies` is one registered object. `abstract`, `decision`, `exploration` and `atom`, the `abstract` recipe and the abstract `status`/`phase` transients are the `vexations` plugin (`src/plugin/vexations.lua`), so `plugins = { vexations = false }` leaves only `task`. Every type extends `basetask` (`vexid`, `description`, `vextype`, `created`, `modified`, `vexbody`, optional `due`/`cost`/`benefit`/`owner`/`manualtags`, and `tags`; `owner` must be one of the config's `taskowners`), and `TaskManager:registertask` merges each type's `schema.atleast` over its parent's merged one, so a type's field replaces its ancestor's definition of that field and inherits the rest. `task` adds `status` (the state machine) and `dependencies`; `atom`, `exploration` and `decision` define their own `status`, and `abstract` has none, only `children`. Each type allows one link set: abstracts `children`, decisions `options`, atoms (and plain tasks and explorations) `dependencies`, and the others are `schema.none` (no value, or an empty one). A dependency target with `children` or `options` throws `dependency-with-children`. A project adds its own types in `.vex/tasks/*.lua` with `task:task 'name':extends 'parent' { schema = ... }`, and transients with `task:transient` (see Transients and Extensions below).

### Focus: the query layer (`src/core/focus.lua`)

A `Focus` is a lazy, composable, **persisted** query over the task index (`.vex/vexdex/focus.bin`). Every operation (`select`, `filter`, `fuzzy`, `match`, `between`, `contains` (a field holding the value as a key or as an element of its list), `tree`, `reversetree`, `step`, set ops) returns a new `Focus` and records itself in `self.operations`, so a focus can be serialized/deserialized and replayed. Named focuses: `all`, `none`, `updated`, `initial`/`interim`/`final` (a filter on the `phase` transient: where each task's `status` sits in its type's state machine, i.e. the initial state, a sink with no outgoing transitions, or neither), `prev` (the default when a verb's `[focus]` arg is omitted), a bare `vexid`, a file/folder path, or a list of any of these (unioned; the CLI turns `a,b` into one). `vex focus <name> [--flags]` builds and saves one; most other verbs (`show`, `get`, `set`, `view`, `resolve`, `remove`) read the saved focus back when no argument is given.

`schema.formatted` falls back to its schema's `interpret` iso when the format iso can't read a value, so every date field reads phrases on add, set and resolve, and a value neither iso reads fails as an ordinary schema `Failure` (the interpret iso's own message, e.g. `naturaltime`'s unknown words with examples), which resolution reports as a normalisation failure. `Focus:interpret()` (`--interpret`) makes the next `filter` or `between` read its values through each field's `interpret` iso before comparing. `date` and `datetime` define that iso with `src/lib/naturaltime.lua`, which reads phrases such as `tomorrow arvo`, `next tuesday` or `3 days ago` relative to the current time, lazily so a saved focus stays relative, and rejects unknown words with `uninterpretable`.

`Focus:groupby(fields...)` is an ordinary operation whose result is a tree of groups, one level per field, each group holding its `field`, `value` and `tasks` (a task list, or the next level's groups). `Focus:chain` runs every operation on each list of tasks in that tree, dropping groups left empty, so `filter`, `orderby(field[, 'desc']...)`, `rn()` (which numbers copies of each group's tasks in `rn`), a further `groupby` and the rest work per group. `Focus:result` returns the tree (`Focus.isgrouped` tells it from a task list), `Focus:groups` its task lists and `Focus:get` flattens it. The `tabular` view applies its flags to the focus in order (`Focus:apply`, without saving it) and puts a subheader above each group. Set operations call `get`, so they gather the groups back into one list. `orderby` reads each task's fields once before sorting.

### Transients (`src/core/task.lua`)

Fields that are never stored, worked out from the task and the vexdex each time they are read. Unlike a schema's `derive`, nothing reaches the task file or the index. Each one is registered against a task type, apart from that type's schema: `task:transient 'wordcount' { vextype = 'task', definition = function(t) ... end }`. They work through `Task.__index`: reading a field a task doesn't hold falls back to `TaskManager:transientof(vextype, name)`, which walks the type's parent chain like `schemaof`. So stored fields always win, subtypes inherit their ancestors' transients (and can override them), a definition can read other transients, and a transient that reads only the task works from the moment `Task.new` wraps it, before it is resolved or indexed; one that queries the vexdex (like `lineage`) needs the task indexed. Nothing else knows about transients: focuses, `vex get` and views read `task[field]` and get them for free (views show them once `--select`ed; `pairs` never sees them). `TaskManager:format` keeps this working on formatted copies by falling back to the unformatted task. Built in on `basetask` (`src/core/taskdefinitions.lua`): `wordcount`, `phase`, `lineage` (ancestor vexids through `children`, root first), `backlinks` and `forwardlinks` (the vexids linking to the task, read with `VexDex:linksto`, and the vexids it links to, found by `TaskManager:forwardlinks` with `Schema:collect` over every `vexlink` in its schemas), `dependents` (the vexids of the tasks that list it in their `dependencies`), `path` (where the task file currently is), `age` (whole days since `created`), `urgency` (1 plus the number of the owner's open tasks with an earlier `due`, so ties share a rank) and `autotags` (the tags whose predicate in `config.autotags` holds, `#` added). `basetask`'s `tags` is a `schema.autotagged`, whose `postvalidate` derives it as `autotags` with `manualtags` applied (`#x` pins a tag, `-#x` suppresses it and wins over a pin). Tags are level-triggered, a pure function of the task, the rules and `manualtags`, so changing a rule loses no manual tag. `due` itself is a `schema.default`: an undated task takes the earliest `due` of the open tasks that depend on it (their `due` is already stored and defaulted, so it is one step), kept in order by the `due-out-of-order` check on `dependencies` (a task may not be due before a dependency; changing a date re-resolves the neighbours, so a bad date is caught from either end). An abstract (from the `vexations` plugin) has no `status` field, so its `status` and `phase` transients come from its children's phases (`todo`/`initial` if all are initial, `done`/`final` if all are final, else `doing`/`interim`), and `resolve` moves the files of a task's ancestors so `paths.groupby` by status follows.

### Views (`src/core/view.lua`)

Pluggable display formats over a focus's task list: `csv`, `tabular`, `list`, `json`, `kanban`, `overview` (scope/structure/movement stats), `singular` (tree + DAG diagram for one task). `vex view [focus] [view]`.

### CLI framework (`src/lib/cli.lua`)

A from-scratch verb/error registry, not a wrapper around an existing arg-parsing library:
- `cli:verb "name" { fn, doc = ..., args = ..., example = ... }` registers a command.
- `cli:error "name" { fn, hint = ... }` registers a named error type; `cli:throw('name', ...)` prints the formatted message + hint to stderr and `os.exit(1)`. All of vex's user-facing errors go through this (see `src/core/errors.lua` for the full catalog) — prefer adding a new named error over an ad hoc `assert`/`error` when something is a user-facing failure rather than a bug.
- Arguments parse into a mixed array/hash `Arguments` table (`args:positional()`, `args:flags()`, `args:text()` for prose, `args:modifiers()`); flag entries carry their own metatable, so tell them apart with `cli.isflag(word)`. Shell quoting survives, so `--vexbody "two words"` is one value.
- A comma outside quotes splits a word into a list, for positionals and flag values alike: `--children a,b` gives `{"a", "b"}` and `vex focus a,b` unions both. Any argv word with whitespace was quoted in the shell, so its commas stay literal (`--vexbody "Fixed, then tested"`); `\,` escapes a comma otherwise. A valueless flag right before another flag modifies it: `vex set x --insert --children a,b` / `--remove --children a` edit a list by value (`TaskManager:set`'s `modifiers`), and `--clear --children` unsets a field (`Arguments:modified` pairs them; any other valueless flag in `set` throws `missing-value`).
- `cli:call` wraps every verb body in `xpcall`, converting any Lua error into a `bug` CLI error with a traceback — a verb function crashing doesn't need its own top-level pcall.

### Storage (`.vex/` and `src/core/vexdex.lua`)

`vex init` creates: `vexdex/` (index + focus, real; the index stores plain task data, and `core.task` puts the `Task` metatable back on every entry when it loads), `config.lua` (read every run, real), `tasks/`, `recipes/`, `focuses/`, `views/` (extensions, see below), `events/`, `plugin/` (project plugins), plus `tmp/` for atomic writes. The vexdex also keeps `backlinks` (`backlinks[target][source] = true` for every `vexlink` from source to target), `paths` (where each task file actually is, relative to `taskfolder`), `fingerprints` (set by `unsafe_add`) and `mtimes` (each file's mtime as vex last saw it, set by `unsafe_stamp`), all saved with the index. Relinking a task (`VexDex:unsafe_link`) takes the links it held before, so it touches only those. `VexDex:taskroot()` is the task folder's absolute path, normalised, so the paths found by walking it match the recorded ones. `TaskManager:getabspath` is where a file *should* be (the `taskpath` plugin); `getcurrentpath` is where it is (`paths`, falling back to `getabspath`). When a task's file isn't at its recorded path (moved by hand, or a stale `paths` after a merge), `TaskManager:read` finds it by filename anywhere under `taskfolder` (`TaskManager:find`), for indexed tasks only, so a new vexid never triggers the walk. The index, backlinks, paths, fingerprints, mtimes and focus are each persisted as a `binser`-serialized `.bin`. `VexDex.new()` walks up from cwd looking for `.vex` when the module loads (see Entry point).

### Config (`src/core/config.lua` / `src/lib/config.lua`)

`core.config` starts from `core.configdefaults` (the table `vex init` builds its `config.lua` from) and registers the global folder's `config.lua` if it exists, then `.vex/config.lua`. `Config:loadall()` `dofile`s each one that exists and merges the returned tables with `func.merge`, later paths overwriting earlier ones key by key (a whole table such as `paths` is replaced, not merged). A file that doesn't run, or doesn't return a table, makes `loadall` return `nil, path, err`, which `core.config` throws as `bad-config-file`. The merged table is then prevalidated and validated against a schema (`lib.schema`): `taskfolder` is a `path` (normalised by `lfsext.normalise`: forward slashes, no `.` segments, repeated or trailing slashes; absolute paths are refused), `loglimit` a non-negative number, `taskowners` and `fingerprint.exclude` lists of strings, `default.tasktype` a string; a wrong value throws `bad-config`. Unknown keys are kept. Read values as fields: `config.taskfolder`, `config.taskowners`, `config.default.tasktype` (the `vextype` `TaskManager:add` gives a task without one), `config.paths`, `config.fingerprint.exclude` (fields left out of a task's fingerprint, `{'modified'}` from `vex init`) `config.autotags` (tag name → predicate of the resolved task, nil by default; anything else throws `bad-autotags`, a predicate that errors throws `tag-rule-failed`) and `config.plugins` (see the plugin system).

`paths.groupby` (read by `src/default/grouppath.lua`, the only `taskpath` member) is a list of field names, transients included, that nests task files in folders, e.g. `paths = { groupby = {'lineage', 'status'} }` puts a task at `<root>/<parent>/<status>/<vexid>.md`. A list value nests one folder per element; unset values and empty lists are skipped; each value is kept to a single folder name (`/`, `\`, `:` and the like become `-`). `core.configdefaults` groups by `{'status', 'lineage'}`; `paths = { groupby = {} }` keeps files flat at `<vexid>.md`. Anything but a list of strings throws `bad-groupby`.

The **global folder** is `lfsext.globaldir()`: `$VEX_HOME`, else `%APPDATA%\vex`, `$XDG_CONFIG_HOME/vex` or `~/.config/vex`, whichever exists first (nil if none). It is the user's own layer under every project, surviving upgrades of the install: `config.lua`, the extension folders below and `plugin/`. Tests point `VEX_HOME` at a missing folder (`test/e2e/helper.lua`, `test/unit/run.sh`) so a developer's real one never leaks in.

### Extensions (`src/core/extensions.lua`)

Required by `src/vex.lua` after every plugin has loaded. For each of `tasks`, `recipes`, `focuses`, `views` then `events`, it runs the `.lua` files of the global folder's copy and then the project's `.vex/<folder>` (each sorted by path) through `loadfile` + `setfenv`, in an environment that exposes `task`, `recipe`, `focus` (the `Focus` class: `focus.register_focus(name, get)`), `view`, `schema` and `event` on top of `_G`, so a file registers things directly (`task:task 'bug':extends 'task' { ... }`) without any `require`. A file that fails to load throws `bad-extension`.

### Events (`src/lib/event.lua`)

A singleton event manager: `event:register(event, handle, fn)` (or `event:on 'name' (fn)`), `event:remove(event, handle)`, `event:trigger(event, ...)`. Handlers run in registration order, then every `*` handler with `(event, ...)`. A failing handler raises a hook error, which `cli:call` turns into the `hook-failed` error, so a hook can stop a command. Every event fires as a `pre-`/`post-` pair: `lib.cli` fires `pre-verb-<verb>` (args) and `post-verb-<verb>` (args, result) around each verb, and each manager fires `<pre|post>-task-<action>`, `focus-write`, `view-display` and `recipe-add` around its public actions (the table with every event's args is in `vexdoc/03 Configuration/06 Configuring event hooks.md`). A new public action on a manager fires its own pair. The vexdex listens on `*`: every event goes to `.vex/vexdex/event-log.txt`, and every `pre-verb-*`'s `args.raw` goes to `verb-log.txt`, which can be replayed to rebuild a project. Both logs are trimmed to `config.loglimit` (default 100) at the start and the end of each command.

**Recurring tasks** are two optional `basetask` fields: `recur` (a `schema.recurrence`, a `naturaltime` phrase such as `weekly` or `3 days`) and `over` (a `schema.datefield`, a field whose schema `collect`s a `date` or `datetime`, defaulting to `due` when `recur` is set). `core.taskdefinitions` registers a `post-task-resolve` hook (handle `recur`) that acts when a task holding `recur` moves into the `final` phase against its previously indexed version (the event's third arg); a rebuilt index, a cascade or a no-op `set` never sees that move. Through the `TaskManager`'s public API only, it copies the task without its `vexid`, `created`, `modified` and `status`, moves `over` on with `naturaltime.parse(recur, from)`, adds and resolves the copy, and inserts it into the parent's `children`.

### Recipes (`src/core/recipe.lua`)

A recipe is a named shortcut producing a task with some fields pre-filled (`Recipe:recipe 'name' { add = function(task, taskproperties) ... end }`). `core.recipe` ships `recurring` (moves `--start` into the `--over` field and adds one task with `recur`) and `repeat` (adds `--n` copies; a missing flag throws `recipe-needs-flag`). The `vexations` plugin adds `abstract`, which forces `vextype = 'abstract'`, and re-registers `recurring` and `repeat` wrapped so that it adds an abstract first and their tasks become its children. The tagger only counts indexed vexids as taken, so a recipe that adds several tasks with one description resolves each as it adds it. A recipe's `add` returns the list of vexids it added; `Recipe:add` resolves them in that order and focuses on all of them. Projects add their own in `.vex/recipes/*.lua` (see Extensions).

### Singletons

`core.task`, `core.vexdex`, `core.focus`, `core.view`, `core.recipe`, `core.config`, `lib.cli`, `lib.plugin` are all modules that `require`-cache a single constructed instance (`return TaskManager.new()` etc. at end of file) rather than exposing a class you instantiate yourself. Requiring the module *is* getting the instance.

## Where code goes

Putting code in the right place matters more here than anywhere else. Each module owns one concern, and new code uses that module's existing machinery rather than rebuilding a smaller copy of it somewhere else. If the machinery for a common need isn't there or isn't easy to use, say so and ask — don't build it from scratch unless that is the assignment.

- **Getting tasks → `src/core/focus.lua`.** Any "which tasks?" question (by vexid, all of them, children, parents, dependencies, backlinks) is a focus: `focus.focus(name)`, `Focus:tree`, `Focus:step`, etc. Don't loop over `vexdex.index` or call `task:getsingle` to assemble task lists elsewhere; add a focus operation if one is missing.
- **Managing tasks → `src/core/task.lua`.** Adding, setting, removing, resolving, reading and writing tasks, and how changes to one task cascade into others, belong to the `TaskManager`.
- **Validating, normalising, deriving and formatting values → `src/lib/schema.lua`** (generic), `src/core/schemaext.lua` (the schema objects vex's tasks are built from: `vexlink`, `status`, `dependencies`, `children` and the link constraints) and `src/core/taskdefinitions.lua` (vex's task types). Formatting is only ever an iso: whatever is formatted must unformat back. Never format values by hand or by walking a schema from outside `schema.lua`; if the schema machinery can't do something it should, fix `schema.lua` itself.
- **Storage → `src/core/vexdex.lua`.** The index, backlinks, paths, file stamps and focus, and how they are persisted.
- **Verbs → `src/core/verbs.lua`.** Thin orchestration of the modules above. Verbs don't know about field names, link formats or other details.
- **Display → `src/core/view.lua`.** Views only present tasks they get from a focus.
- **User-facing errors → `src/core/errors.lua`.**
- **Generic helpers → `src/lib/func.lua`** (and the other `src/lib` modules). Check what exists (e.g. `func.ifilter`, `func.ireduce`, `func.imerge`) before writing a loop.

If a new concept appears and it isn't clear which of these it belongs to, stop and discuss it with the user before writing code.

## Conventions

- Metatable-based "OO": `Module.new()` + `Module.__index = Module`, methods as `function Module:method(...)`.
- No explanatory comments. Code should read clearly on its own; the few existing comments (e.g. the workarounds in `test/e2e/helper.lua`) only record a non-obvious *why*.

## Repo preferences

- **Take in changes after a checkout.** `.vex/vexdex/` is git-ignored, so run `./src/vex resolve all` after cloning, pulling or switching branches (`--force` if `.vex/config.lua` or a task type changed). It only rewrites files whose content changes.
- **Track work with vex.** This repo's backlog is vex tasks in `vexdoc/vex/`. When new work or a new bug comes up, raise it with `./src/vex add <description>`, then give the task a body that fully describes it.
- **Organise tasks as a tree of abstracts over atoms.** Every task you create or edit sits under an `abstract` (`--vextype abstract`) that names a category of work in a few words ("Make vex configurable from config", "Fix bugs"); abstracts nest to refine categories downwards, hold only `children`, and have no body. The leaves are `atom`s (`--vextype atom`): one concrete change small enough to finish in a single session, with a body that says what is wrong or missing, where in the code, which doc promises it (link pages as `[[Page name]]` and tasks as `[[vexid]]`), and how to verify it. If an atom needs breaking down, it should have been an abstract: add one and move the pieces under it. Put a new task under the closest existing abstract with `vex set <parent> --insert --children <vexid>` (remove it from its old parent first, since a task has one parent), add a new abstract only for a new category, and link ordering between atoms with `--dependencies`. `paths.groupby` files each task under its status and lineage, so the folders in `vexdoc/vex/` mirror this tree.
- **Close out vex tasks** that a change addresses: set its status to `done` with `./src/vex set <vexid> --status done` (`todo` goes straight to `done`; an abstract's `doing` is derived from its children). Append to a task's body rather than overwriting it, and only when there is something worth adding: a `done` status already says the task was fixed.
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
