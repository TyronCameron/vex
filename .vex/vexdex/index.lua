{
  add-transient-fields-computed-1 = {
    created = 1792202853,
    description = "Add transient fields computed on read",
    modified = 1792203149,
    status = "done",
    vexbody = "Transients are task fields that are never stored but computed every time they are read, from the task itself and the vexdex. Unlike schema `derive` fields, nothing about them reaches the task file or the index.\
\
A transient is registered on a task type, kept apart from the task type's schema: `task:transient 'wordcount' { vextype = 'task', definition = function(t) ... end }`. Subtypes inherit their ancestors' transients and can override them. Projects add their own in `.vex/tasks/*.lua`.\
\
They work through `Task.__index`: reading a field a task doesn't hold falls back to the transient of that name for the task's type, so stored fields always win, only the transient asked for is computed, transients can use each other, and they work from the moment a task exists in memory (before it is resolved, indexed or written). Focuses read `task[field]`, so `filter`, `fuzzy`, `select`, `tree` and views get transients with no extra code. `vex get <vexid> --<transient>` reads them too.\
\
Built-in transients on `task`: `wordcount` (words in the description), `phase` (initial, interim or final in the status state machine; the `initial`/`interim`/`final` focuses filter on it), `ancestors` (parent vexids, nearest first), `path` (absolute path of the task file) and `age` (whole days since creation).",
    vexid = "add-transient-fields-computed-1",
    vextype = "task"
  },
  cli-pass-raw-args-1 = {
    created = 1779228684,
    description = "CLI should pass raw args",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. `CLI:run` now keeps the original raw string it was invoked with (before verb-name removal or tokenizing) and stashes it as `args.raw` on the parsed `Arguments` table it passes to the verb - so any verb can reach the exact, unsplit text a user typed after `vex`, alongside the already-tokenized positional/flag view. No built-in verb consumes it yet; it's there for verbs (built-in or user-defined) that want to do their own parsing. Covered by a new test in `test/unit/lib/cli_spec.lua`.",
    vexid = "cli-pass-raw-args-1",
    vextype = "task"
  },
  create-events-file-slip-1 = {
    created = 1783721405,
    description = "Create events file and slip in events architecture",
    modified = 1792203107,
    status = "todo",
    vexbody = "See [[Events and hooks]]\
\
",
    vexid = "create-events-file-slip-1",
    vextype = "task"
  },
  create-linking-including-fixing-1 = {
    created = 1783721154,
    description = "Create linking, including fixing children and parent fields",
    modified = 1792203107,
    status = "done",
    vexbody = "\
Fixed. `children` on an abstract stays the single source of truth for parent links; there is no stored `parent` field.\
\
- `--tree`/`--reversetree` (`core/focus.lua`) look tasks up by vexid, tolerate missing fields, and run `optic.traverse` from each focused task.\
- `children` entries fail with `multiple-parents` when a task is already another abstract's child, and `dependencies` entries fail with `dependency-cycle` on a cycle (`core/errors.lua`).\
- `schema.lua`'s `apply`/`unapply` run isos through container schemas, so `TaskManager:format` is `schema:apply('format', ...)`, and `children` and `dependencies` are written as `[[links]]`. `all` runs every subschema's prevalidate/postvalidate, and postvalidate now reaches through wrapper schemas.\
- `vexlink` records each link during resolve, and the vexdex keeps them as backlinks (`vexdex/backlinks.bin`), exposed as `Focus:backlinks()`. `TaskManager:remove` uses them to strip the removed vexid from every property of each linking task, then resolves and rewrites those tasks.\
- The `singular` view lists the parent chain, children, what the task depends on and what depends on it. The overview's \"nil parent\" stat uses `reversetree('children')`.\
\
Covered by unit tests in `test/unit/core/{focus,task,taskdefinitions,vexdex}_spec.lua` and `test/unit/lib/schema_spec.lua`, plus `test/e2e/linking_spec.lua`.\
",
    vexid = "create-linking-including-fixing-1",
    vextype = "task"
  },
  create-milestones-1 = {
    created = 1781730463,
    description = "Create Milestones",
    modified = 1792203107,
    status = "todo",
    vexbody = "\
Need to create milestones:\
\
- v0.0.1 working but unstable \
- V0.1.0 working and stable and usable on other projects\
- v1.0.0 working and stable and feature-stable (unlikely to change)\
\
These make good abstracts. \
\
Furthermore, because a parent is defined through children, can have multiple parents ??? Maybe worth making milestones tags instead of abstracts? \
\
\
",
    vexid = "create-milestones-1",
    vextype = "task"
  },
  create-report-view-1 = {
    created = 1779226044,
    description = "Create report view",
    modified = 1792203107,
    status = "todo",
    vexbody = "\
I want this view to show all tasks in the form of a markdown report. \
So starting at high level categories and working the way downwards (children tasks). \
It should show status, completion rates for each subgroup. \
It should show pending decisions, unexplored areas. \
It should show dependency graphs. \
It should use the description fields, not the actual bodies.\
",
    vexid = "create-report-view-1",
    vextype = "task"
  },
  create-view-next-up-1 = {
    created = 1779309094,
    description = "Create view next up. This view shows unblocked tasks, in order or priority.",
    modified = 1792203107,
    status = "todo",
    vexbody = "",
    vexid = "create-view-next-up-1",
    vextype = "task"
  },
  decide-how-between-takes-1 = {
    created = 1792116143,
    description = "Decide how between takes datetime bounds",
    modified = 1792203107,
    status = "todo",
    vexbody = "Design decision, raised while fixing [[fix-between-focus-crashing-1]]. `--between field:begin:end` now converts each bound through the field's schema, so `cost:1:9` works. Datetime fields (`due`, `created`, `modified`) cannot be filtered yet, for two reasons. `Focus.parse` splits flag values on `:`, so a full `YYYY-MM-DD HH:MM:SS` bound is torn apart. And the `datetime` schema's format iso only accepts a full date and time, so a date-only bound like `2026-01-01` does not parse. Today such a bound gives a usage error (\"Cannot compare `due` with `2026-01-01`\").\
\
Options: (a) let `datetime` also read a date-only value as midnight; (b) give `between` a separator that cannot appear in a datetime (e.g. `due:2026-01-01..2026-06-01`); (c) both. The pending row in `test/e2e/smoke_spec.lua` (`--between due:...`) should pass once this is decided.",
    vexid = "decide-how-between-takes-1",
    vextype = "task"
  },
  ensure-verbs-return-data-1 = {
    created = 1779226066,
    description = "Ensure all verbs return data and do not print",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. Every verb (`show`, `focus`, `view`, `remove`, `get`, `recipe` in `core/verbs.lua`, plus the built-in `help` verb in `lib/cli.lua`) previously called `print`/`pretty.print` directly, mid-verb, instead of returning a value. They now build up a list of output lines and `return table.concat(lines, \"\\n\")` (via a small `join_lines` helper that returns `nil` rather than `\"\"` when there's nothing to say, so a verb that produced no output before still produces none). `CLI:run` already printed a verb's string/number return value once at the top level - that single `print` call reproduces the exact same terminal output as the old per-line `print`/`pretty.print` calls, since each of those always emitted its own trailing newline.\
\
Terminal output is unchanged (verified via the e2e suite and manual runs), but every verb is now independently callable through `CLI:call` and testable/composable without capturing stdout.",
    vexid = "ensure-verbs-return-data-1",
    vextype = "task"
  },
  fail-atomic-write-cannot-rename-1 = {
    created = 1792192318,
    description = "Fail loudly when an atomic write cannot rename",
    modified = 1792203107,
    status = "todo",
    vexbody = "VexDex:atomic (src/core/vexdex.lua) ignores os.rename's result. If the target folder is missing (e.g. .vex/vexdex/ in a fresh clone, since git does not track empty folders), every write is silently dropped: vex resolve all exits 0, writes no index, and leaves its temp files behind in .vex/tmp. It should throw a named CLI error (e.g. the existing write error) when the rename fails, and the e2e storage spec should cover a missing vexdex folder.",
    vexid = "fail-atomic-write-cannot-rename-1",
    vextype = "task"
  },
  fix-between-focus-crashing-1 = {
    created = 1792069229,
    description = "Fix between focus crashing on CLI values",
    modified = 1792203107,
    status = "done",
    vexbody = "Found by the e2e smoke test. `vex focus all --between created:0:9999999999` crashes with an Internal error: `Focus:between` (`src/core/focus.lua`) compares the raw CLI strings `start`/`finish` with the task's field (`attempt to compare string with number`). The bounds need converting through the field's schema (e.g. `due` as a datetime, `cost` as a number) before comparing.\
\
Fixed for numeric bounds. Datetime bounds need a design decision first, tracked in [[decide-how-between-takes-1]].",
    vexid = "fix-between-focus-crashing-1",
    vextype = "task"
  },
  fix-decision-constraint-crashing-1 = {
    created = 1792069346,
    description = "Fix decision constraint crashing",
    modified = 1792203107,
    status = "done",
    vexbody = "Found by the new task round-trip unit test. The `decision` field's constraint in `src/core/taskdefinitions.lua` is written as `function(self, instance, context)`, but `schema.constraint` calls its function with `(instance, context)` (compare `acyclic(dependency, context)`). So `context` is nil, and setting `decision` on any decision task crashes resolution (\"attempt to index local 'context'\").",
    vexid = "fix-decision-constraint-crashing-1",
    vextype = "task"
  },
  fix-exploration-tasks-crashing-1 = {
    created = 1792069229,
    description = "Fix exploration tasks crashing on add",
    modified = 1792203107,
    status = "done",
    vexbody = "Found by the e2e smoke test. `vex add Explore some options --vextype exploration` crashes with an Internal error: the `empty` schema (`src/lib/schema.lua`) takes `#instance` of a nil `vexbody`. An exploration with no body yet should either resolve or fail validation with a named error.",
    vexid = "fix-exploration-tasks-crashing-1",
    vextype = "task"
  },
  fix-file-path-focuses-1 = {
    created = 1792069646,
    description = "Fix file path focuses",
    modified = 1792203107,
    status = "done",
    vexbody = "Found by the new e2e smoke test. `vex focus ./some-task-1.md` (or an absolute path to a task file) focuses on 0 vexes: `namedfocus.from_file_path` (`src/core/focus.lua`) strips the folders but keeps the `.md` extension, then looks `some-task-1.md` up in the index, which is keyed by vexid. It should find the task by its path (see also [[fix-folder-path-focuses-1]], which builds on this).",
    vexid = "fix-file-path-focuses-1",
    vextype = "task"
  },
  fix-focus-binary-ops-cli-1 = {
    created = 1783339200,
    description = "Fix union/intersect/xor/notin/onlyin crashing from the CLI",
    modified = 1792203107,
    status = "done",
    vexbody = "\
Confirmed by testing: `vex focus all --union all`, `--intersect all`, and (by the same code path) presumably `--xor`/`--notin`/`--onlyin` all crash with \"Internal error ... attempt to call method 'get' (a nil value)\". `Focus:union`/`Focus:intersect`/etc. (`core/focus.lua`) expect a Focus *object* as their argument (they call `focus:get(tasks)` on it), but `Focus.parse` passes whatever raw string came from the CLI flag value (e.g. `\"all\"`) straight through — never resolving it to an actual named focus first. `--complement` works fine since it takes no argument at all. Needs `Focus.parse` (or the binary-op methods themselves) to resolve a string argument through `namedfocus.focus(...)` before calling it.\
",
    vexid = "fix-focus-binary-ops-cli-1",
    vextype = "task"
  },
  fix-focus-parse-registering-1 = {
    created = 1792069229,
    description = "Fix Focus parse registering no-focus",
    modified = 1792203107,
    status = "done",
    vexbody = "`Focus.parse` (`src/core/focus.lua`) calls `cli:error('no-focus')`, which registers a new (empty) `no-focus` error type, instead of `cli:throw('no-focus')`. When there is no current focus it carries on with a nil focus.",
    vexid = "fix-focus-parse-registering-1",
    vextype = "task"
  },
  fix-focusfocus-dropping-unions-1 = {
    created = 1792016373,
    description = "Fix Focus.focus dropping unions",
    modified = 1792203107,
    status = "todo",
    vexbody = "`Focus.focus(...)` in `src/core/focus.lua` calls `focus:union(namedfocus.focus(focusname))` for every name after the first and throws the result away, so `Focus.focus(\"a\", \"b\")` only ever returns `a`. It should be `focus = focus:union(...)`.",
    vexid = "fix-focusfocus-dropping-unions-1",
    vextype = "task"
  },
  fix-folder-path-focuses-1 = {
    created = 1792016374,
    description = "Fix folder path focuses",
    modified = 1792203107,
    status = "done",
    vexbody = "`namedfocus.from_folder_path` (`src/core/focus.lua`) inserts `namedfocus.from_file_path(path)` for each file it walks: a Focus object built from the folder path, not the task. A folder focus therefore returns focus objects instead of tasks. It should look up each walked file's task. `recursive_dir_walk` also passes bare names from `lfs.readdir` to `lfs.attributes`; check that those resolve against the folder.",
    vexid = "fix-folder-path-focuses-1",
    vextype = "task"
  },
  fix-func-last-off-1 = {
    created = 1792016374,
    description = "Fix func last off by one",
    modified = 1792203107,
    status = "done",
    vexbody = "`func.last(tab, n)` (`src/lib/func.lua`) slices from `#tab - n`, returning `n + 1` elements (e.g. `func.last({1,2,3})` gives `{2,3}`). It should start at `#tab - n + 1`. Needs a test in `func_spec.lua`.",
    vexid = "fix-func-last-off-1",
    vextype = "task"
  },
  fix-func-map-any-1 = {
    created = 1791929695,
    description = "Fix func map and any helpers",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. func.map writes res[i]. count, any and all name their predicate f, so the func module is no longer shadowed. any and all are seeded with false and true, so empty tables work. count counts the values of the sparse filter result.",
    vexid = "fix-func-map-any-1",
    vextype = "task"
  },
  fix-func-slice-default-1 = {
    created = 1792016374,
    description = "Fix func slice default end",
    modified = 1792203107,
    status = "done",
    vexbody = "`func.slice(tab, n)` (`src/lib/func.lua`) is meant to default `end_idx` to `start_idx` (and `start_idx` to 1). But it compares `end_idx < start_idx` before that, so a nil `end_idx` raises \"attempt to compare nil with number\". The `\"end\"`/`\"begin\"` string forms also hit numeric comparisons. Move the defaulting first and add tests.",
    vexid = "fix-func-slice-default-1",
    vextype = "task"
  },
  fix-init-requires-existing-vex-1 = {
    created = 1783339200,
    description = "Fix vex init crashing outside an existing .vex tree",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. src/vex.lua already skips loading plugins for init, so vex init works in a fresh directory with no .vex above it (checked by hand).",
    vexid = "fix-init-requires-existing-vex-1",
    vextype = "task"
  },
  fix-list-field-roundtrip-1 = {
    created = 1783339200,
    description = "List-typed fields never survive a disk round-trip",
    modified = 1792203107,
    status = "done",
    vexbody = "\
Fixed. `src/default/obsidian.lua`'s `read` now tracks the last real key seen while scanning frontmatter lines, and accumulates indented `- item` continuation lines into a table under that key, matching the multi-line array format `to_yaml_value` (the writer, same file) already produced. A written array like:\
\
```yaml\
children:\
  - \"[[some-task]]\"\
```\
\
now reads back as a real Lua table (`children = {\"[[some-task]]\"}`), not `children = \"\"`.\
\
Empty lists needed a separate tweak: `to_yaml_value` couldn't previously distinguish an empty array from an empty map (both produced a bare, stray blank line), so a schema-defaulted `children = {}` round-tripped to `\"\"` too. `to_yaml_value` now serializes any empty table as `[]`, and `read` recognises a literal `[]` value as an explicit empty table. `vex add X --vextype abstract` followed by `vex resolve all` — twice in a row — now succeeds both times. Covered by new unit tests in `test/unit/default/obsidian_spec.lua` and an e2e regression in `test/e2e/lifecycle_spec.lua`.\
\
Note: this only fixes the disk round-trip. Setting a list field directly via a CLI flag (`--children`/`--dependencies`/`--options`) is still not implemented — that's tracked separately in `implement-cli-list-fields-1`.\
",
    vexid = "fix-list-field-roundtrip-1",
    vextype = "task"
  },
  fix-lux-entry-point-1 = {
    created = 1783339200,
    description = "Fix lux.toml entry point mismatch",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. lux.toml now runs src/vex.lua, the real entry point.",
    vexid = "fix-lux-entry-point-1",
    vextype = "task"
  },
  fix-optic-cartesian-product-1 = {
    created = 1792016374,
    description = "Fix optic cartesian product",
    modified = 1792203107,
    status = "done",
    vexbody = "`Optic.cartesian` (`src/lib/optic.lua`) cannot work. `increment_multi_index` loops `for i = #indexes, 1` with no `-1` step, so it runs at most once. `cartesian_product_gen` assigns to undefined globals `index` / passes `index` instead of `indexes`. Its cardinality fold seeds with the number `1`, not a `Cardinality`. Nothing uses it yet. Fix it with tests, or remove it.",
    vexid = "fix-optic-cartesian-product-1",
    vextype = "task"
  },
  fix-status-transition-enforcement-1 = {
    created = 1783339200,
    description = "Status state machine doesn't actually reject invalid transitions",
    modified = 1792203107,
    status = "done",
    vexbody = "\
Fixed. The `statemachine` schema (`core/taskdefinitions.lua`) used to cache one machine on `self.extra`, shared by every task, and seed it from `context.task.status`, which `TaskManager:set` had already overwritten. Now `set` builds a new task instead of changing the indexed one, `resolve` passes the indexed version as `context.previous`, and `prevalidate` builds a fresh `statemachine.new` from that previous status. `todo -> done` and `doing -> todo` now fail with `resolution-failed-validation`. An unchanged status is always valid, so `vex resolve all` accepts whatever is on disk, and a new task with no status gets `todo`. `lib/statemachine.lua`'s `preprocess` copies state definitions instead of mutating them, so a machine can be built more than once from the same definition. `version-01-1` got `children: []` so `vex resolve all` completes. Covered by `test/unit/core/taskdefinitions_spec.lua`, `test/unit/core/task_spec.lua` and an e2e test in `test/e2e/lifecycle_spec.lua`.\
",
    vexid = "fix-status-transition-enforcement-1",
    vextype = "task"
  },
  fix-throw-unregistered-error-1 = {
    created = 1792069229,
    description = "Fix throw with unregistered error crashing",
    modified = 1792203107,
    status = "done",
    vexbody = "`CLI:throw` (`src/lib/cli.lua`) reads `self.errors[errtype][1]` before checking whether `errtype` is registered, so throwing an unknown error name crashes with \"attempt to index a nil value\" instead of reaching its own \"Unknown error type\" fallback.",
    vexid = "fix-throw-unregistered-error-1",
    vextype = "task"
  },
  fix-typed-field-cli-input-1 = {
    created = 1783339200,
    description = "Fix numeric and datetime fields failing validation from the CLI",
    modified = 1792203107,
    status = "done",
    vexbody = "\
Fixed. Two independent bugs were stacked here:\
\
1. `schema.num` (`src/lib/schema.lua`) had no `prevalidate` at all, so a CLI-supplied string like `\"15\"` was never coerced to a number before `validate` ran.\
2. `schema.maybe`'s `prevalidate` delegated to the shared `prevalidate_children` helper, which only descends when `type(instance) == \"table\"`. That gate is correct for real table containers (`exactly`/`atmost`/`atleast`/`vec`) but wrong for `maybe`, whose own `iterate` always yields `instancekey = nil` (it wraps a single value, not table members) — so the wrapped schema's `prevalidate` (the `num` coercion above, and `formatted{datetime}`'s existing, already-correct string→epoch conversion) never even ran for `due`, `cost`, or `benefit`, all of which are `maybe`-wrapped.\
\
`formatted`'s own `unapply('format', ...)` conversion was not itself buggy, as originally suspected — it was simply never reached.\
\
Fix: added the `num` coercion, and rewrote `maybe`'s `prevalidate` to use an unconditional loop (matching the pattern `default`/`derive` already used) instead of the table-gated helper. `vex add Buy new mug --cost 15 --benefit 40 --due 2026-08-01T09:00:00` now resolves cleanly, as does hand-editing a `due`/`cost`/`benefit` value directly into a task file and running `vex resolve`. Covered by new unit tests in `test/unit/lib/schema_spec.lua` and e2e coverage in `test/e2e/lifecycle_spec.lua`.\
",
    vexid = "fix-typed-field-cli-input-1",
    vextype = "task"
  },
  fix-unknownvextype-naming-nil-1 = {
    created = 1792069230,
    description = "Fix unknown-vextype naming nil type",
    modified = 1792203107,
    status = "done",
    vexbody = "`TaskManager:resolve` (`src/core/task.lua`) throws `unknown-vextype` with `vextype`, which is nil at that point, instead of `task.vextype`. `vex add Hello there --vextype nope` prints \"Type = nil\" rather than naming `nope`.",
    vexid = "fix-unknownvextype-naming-nil-1",
    vextype = "task"
  },
  fix-vex-get-crashing-list-fields-1 = {
    created = 1792203107,
    description = "Fix vex get crashing on list fields",
    modified = 1792203107,
    status = "todo",
    vexbody = "`vex get <vexid> --children` (or any field holding a list, such as `dependencies`, `options` or the `ancestors` transient) crashes with an `Internal error`: `Task:tostring` in `src/core/task.lua` passes each value straight to `table.concat`, which only takes strings and numbers. Seen on main before transients existed. List values need a printable form (e.g. comma-separated, matching how list flags are written).",
    vexid = "fix-vex-get-crashing-list-fields-1",
    vextype = "task"
  },
  fix-vex-suggest-crashing-1 = {
    created = 1792069229,
    description = "Fix vex suggest crashing",
    modified = 1792203107,
    status = "done",
    vexbody = "Found by the e2e smoke test and luacheck. `suggest.suggest` (`src/plugin/vexcomplete.lua`) writes debug output to a hardcoded `/home/tyronc/Nextcloud/projects/vex/.vex/current.txt`, so `vex suggest ...` crashes on any other machine. `suggest.recipe` also reads an undefined global `recipe` (`core.recipe` is never required). Shell completion is broken until both are fixed.",
    vexid = "fix-vex-suggest-crashing-1",
    vextype = "task"
  },
  fix-views-crashing-empty-1 = {
    created = 1792069418,
    description = "Fix views crashing on empty focus",
    modified = 1792203107,
    status = "done",
    vexbody = "Found by the new view unit tests. With an empty focus (e.g. `vex view none csv`), the `csv` view crashes in `func.lua` (`pairs` on nil), `kanban` crashes in `view.lua` (`ipairs` on nil) and `singular` indexes a nil task. An empty focus should render an empty view, and `singular` should throw a usage error like it does for more than one task.",
    vexid = "fix-views-crashing-empty-1",
    vextype = "task"
  },
  implement-categorical-variables-1 = {
    created = 1783721588,
    description = "Implement categorical variables",
    modified = 1792203107,
    status = "done",
    vexbody = "Closed: no new machinery needed. A categorical variable is schema.any over constants, e.g. schema.any {'low', 'medium', 'high'}; covered by a test in schema_spec.lua. The owner field is the first one that uses it.",
    vexid = "implement-categorical-variables-1",
    vextype = "task"
  },
  implement-cli-list-fields-1 = {
    created = 1783339200,
    description = "Support list-typed fields as CLI flags",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed for focuses: vex focus a,b,c works. from_comma_sep called a function that doesn't exist, and is now saved under its own name, so the prev focus replays it. Comma-separated list flags like --dependencies a,b are split out into their own task.",
    vexid = "implement-cli-list-fields-1",
    vextype = "task"
  },
  implement-config-defaults-1 = {
    created = 1783339200,
    description = "Wire up config.lua's default.* and plugins.* keys",
    modified = 1792203107,
    status = "todo",
    vexbody = "\
`vex init`'s default `config.lua` writes a `default` table (taskformat, view, dataformat, option, tasktype) and a `plugins` table (vexations, inline), but nothing in the codebase reads any of these keys — only `taskfolder` is actually consulted (`core/task.lua`). Found while writing the wiki's Configuring vex (config.lua) page. At minimum, `default.view` should give `vex view <focus>` a fallback so a lone argument doesn't have to be read as the view name.\
",
    vexid = "implement-config-defaults-1",
    vextype = "task"
  },
  implement-event-hooks-1 = {
    created = 1783339200,
    description = "Implement event hooks",
    modified = 1792203107,
    status = "todo",
    vexbody = "\
`.vex/events` is created by `vex init` but nothing reads it. `lib/event.lua` is still `return {}`. Wire up `pre-[verb]`/`post-[verb]` dispatch so files dropped in `.vex/events` can hook into resolution — found while writing the wiki's Configuring event hooks page, which currently has to document this as intent rather than behaviour.\
",
    vexid = "implement-event-hooks-1",
    vextype = "task"
  },
  implement-focus-interpret-1 = {
    created = 1783339200,
    description = "Implement Focus:interpret",
    modified = 1792203107,
    status = "todo",
    vexbody = "\
`Focus:interpret()` in `core/focus.lua` currently just hard-throws (\"this is a hard feature that I don't know how to do yet\"). The intent is that `--interpret` before a flag would convert natural-language values (e.g. `due:tomorrow`) before matching. Needed before any doc can honestly show `--interpret` working.\
",
    vexid = "implement-focus-interpret-1",
    vextype = "task"
  },
  implement-focus-loader-1 = {
    created = 1783339200,
    description = "Load custom named focuses from .vex/focuses",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. core/extensions.lua also runs .vex/focuses/*.lua with focus (the Focus class) in scope, so a file just calls focus.register_focus('name', function() ... end). Saved focuses replay by name, so they keep working.",
    vexid = "implement-focus-loader-1",
    vextype = "task"
  },
  implement-inline-plugin-1 = {
    created = 1783339200,
    description = "Build the inline mode plugin",
    modified = 1792203107,
    status = "todo",
    vexbody = "\
`config.lua`'s default `plugins.inline = true` references a plugin that doesn't exist — no `inline` file under `src/plugin` or `src/default`. Build the `#vex Description` inline-tag tracking and the `open`/`inline` verbs described in the design journal (Vex.md's \"Watch mode / plugin\" section).\
",
    vexid = "implement-inline-plugin-1",
    vextype = "task"
  },
  implement-owner-assignment-1 = {
    created = 1783339200,
    description = "Make owner a real, validated field",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. owner is an optional field on the base task type: schema.maybe {schema.any(config.users)}. List the allowed owners under users in .vex/config.lua (vex init writes users = {}). With no users configured, every owner is rejected; to make that work, schema.any over an empty list now matches nothing.",
    vexid = "implement-owner-assignment-1",
    vextype = "task"
  },
  implement-priorityorder-variables-1 = {
    created = 1783721600,
    description = "Implement priority/order variables",
    modified = 1792203107,
    status = "todo",
    vexbody = "Implement ordering variables which can have either or both of: 1) no gaps between orderings and 2) no ties between orderings\
\
- Implement priority with no gaps and no ties\
\
- `vex set my-task-1 --priority 3` sets the task to 3 and bumps everything higher; also, priority fails if there is a due date. Due date should fail if there is a priority. Priority is about urgency.\
\
- Implement importance with no gaps and no ties",
    vexid = "implement-priorityorder-variables-1",
    vextype = "task"
  },
  implement-recipe-loader-1 = {
    created = 1783339200,
    description = "Load custom recipes from .vex/recipes",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. core/extensions.lua also runs .vex/recipes/*.lua with recipe in scope, so a file just calls recipe:recipe 'name' { add = function(task, taskproperties) ... end }.",
    vexid = "implement-recipe-loader-1",
    vextype = "task"
  },
  implement-task-type-loader-1 = {
    created = 1783339200,
    description = "Load custom task types from .vex/tasks",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. The new core/extensions.lua runs every .lua file in .vex/tasks with task and schema in scope (via setfenv), so a file just calls task:task 'bug':extends 'task' { schema = ... }. Files load in path order, so a parent type must sort before its children. A broken file throws bad-extension.",
    vexid = "implement-task-type-loader-1",
    vextype = "task"
  },
  implement-vexations-plugin-1 = {
    created = 1783339200,
    description = "Build the vexations plugin",
    modified = 1792203107,
    status = "todo",
    vexbody = "\
`config.lua`'s default `plugins.vexations = true` references a plugin that doesn't exist — no `vexations` file under `src/plugin` or `src/default`. Per the design journal, this should be the opinionated bundle of the 4 task types (exploration/abstract/decision/atom) as an optional layer on top of the plain `task` type.\
",
    vexid = "implement-vexations-plugin-1",
    vextype = "task"
  },
  implement-view-loader-1 = {
    created = 1783339200,
    description = "Load custom views from .vex/views",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. core/extensions.lua also runs .vex/views/*.lua with view in scope, so a file just calls view:view 'name' { display = function(focus, flags) ... end }.",
    vexid = "implement-view-loader-1",
    vextype = "task"
  },
  keep-task-modified-time-1 = {
    created = 1792192319,
    description = "Keep each task's modified time when reindexing",
    modified = 1792203107,
    status = "todo",
    vexbody = "TaskManager:reindexall resolves every task read from disk, and the modified field is a schema.derive that always returns os.time(). So vex resolve all stores the rebuild time as every task's modified in the index, while the task files keep their real modified time. The index no longer mirrors the files, and anything that compares modified (the updated focus, sorting by modified) sees every task as just changed. Resolving a task read from disk should keep its stored modified, and only a real change (add/set) should bump it.",
    vexid = "keep-task-modified-time-1",
    vextype = "task"
  },
  load-config-files-hierarchically-1 = {
    created = 1792069230,
    description = "Load config files hierarchically",
    modified = 1792203107,
    status = "todo",
    vexbody = "`Config:loadall` (`src/lib/config.lua`) supports several paths, later ones overriding earlier ones, but `src/core/config.lua` only registers `.vex/config.lua`. The design goal is an inheritance chain (e.g. user-level config, then each `.vex` from the outermost to the innermost), none of which is wired up.",
    vexid = "load-config-files-hierarchically-1",
    vextype = "task"
  },
  make-claude-review-docs-1 = {
    created = 1783721651,
    description = "Make claude review docs",
    modified = 1792203107,
    status = "todo",
    vexbody = "Make claude review the docs. It wrote a stack of \"not done\" and \"this is actually implemented right now\" in the code ... that's dumb, I don't want any of that in the docs. The docs should read as fact. ",
    vexid = "make-claude-review-docs-1",
    vextype = "task"
  },
  make-cli-understand-quoting-1 = {
    created = 1783721534,
    description = "make CLI understand quoting",
    modified = 1792203107,
    status = "done",
    vexbody = "\
Fixed. `lib/cli.lua`'s `parse_args` used to split on bare whitespace (`%S+`), so a shell-quoted flag value containing a space (e.g. `--filter status:\"not done\"`) got torn back into two tokens the moment `vex.lua` rejoined `arg` with `table.concat(arg, \" \")` and handed it back to the parser. It now tokenizes with a small POSIX-style scanner: single quotes are fully literal, double quotes allow `\\\"`/`\\\\`/`\\$`/`` \\` `` escapes, a bare backslash escapes the next character outside quotes, and a quoted segment glues onto adjacent unquoted text into one word (so `status:\"not done\"` reads back as `status:not done`, and the classic `don'\\''t` idiom reads back as `don't`).\
\
That alone wasn't enough, since `vex.lua` was reassembling `arg` with a plain space-join before parsing, which throws away the word boundaries the shell already established. `CLI:rawify(argv)` now quotes any word that needs it (containing whitespace, a quote character, or a backslash) before joining, so the round trip through `parse_args` reproduces the original argv exactly. `vex.lua` calls `cli:rawify(arg)` instead of `table.concat(arg, \" \")`. Covered by new tokenizer tests in `test/unit/lib/cli_spec.lua`.\
",
    vexid = "make-cli-understand-quoting-1",
    vextype = "task"
  },
  make-config-actually-control-1 = {
    created = 1783721641,
    description = "Make config actually control plugins",
    modified = 1792203107,
    status = "todo",
    vexbody = "",
    vexid = "make-config-actually-control-1",
    vextype = "task"
  },
  make-vexids-phrase-aware-length-1 = {
    created = 1792069491,
    description = "Make vexids phrase-aware and length-flexible",
    modified = 1792203107,
    status = "done",
    vexbody = "The default tagger (src/default/canonicalvexid.lua) took the first 4 non-filler words, so ids were truncated at a fixed count, leaked prepositions like into/outside, glued punctuated words together (luxtoml, focusfocus) and dropped negation. It now keeps the first sentence, splits on punctuation (keeping the first of slash alternatives), drops filler words and -ly adverbs, keeps negation (doesn't -> not), and treats prepositions/subordinators as phrase boundaries: the main clause fills a 32-char / 6-word budget first, prepositional phrases only if room remains. No data files or dependencies.",
    vexid = "make-vexids-phrase-aware-length-1",
    vextype = "task"
  },
  persist-task-recipe-adds-1 = {
    created = 1792069230,
    description = "Persist every task a recipe adds",
    modified = 1792203107,
    status = "todo",
    vexbody = "`Recipe:add` (`src/core/recipe.lua`) only resolves and writes the single vexid the recipe's `add` function returns, so a recipe that calls `task:add` several times only persists the last task (see the recipe example in `vexdoc/Home.md`). Every task a recipe adds should be resolved and written.",
    vexid = "persist-task-recipe-adds-1",
    vextype = "task"
  },
  put-normalise-validate-derive-1 = {
    created = 1779449388,
    description = "Put normalise, validate, and derive into lib.schema",
    modified = 1792203107,
    status = "done",
    vexbody = "",
    vexid = "put-normalise-validate-derive-1",
    vextype = "task"
  },
  record-onlyin-focus-operations-1 = {
    created = 1792016373,
    description = "Record onlyin focus operations",
    modified = 1792203107,
    status = "done",
    vexbody = "`Focus:onlyin` (`src/core/focus.lua`) is the only set operation that passes no `operations` to `Focus.new`, so it falls back to `{focus, {\"onlyin\"}}`. Saving and replaying such a focus throws `unknown-focus onlyin`. It should record `{operation = \"onlyin\", ...}` like `notin` does.",
    vexid = "record-onlyin-focus-operations-1",
    vextype = "task"
  },
  retire-lib-optic-vex-1 = {
    created = 1792192252,
    description = "Retire lib.optic from vex",
    modified = 1792203107,
    status = "todo",
    vexbody = "src/lib/optic.lua (435 lines, plus test/unit/lib/optic_spec.lua) is a general-purpose optics library (field/iso/filter/fold/traverse/chain/fanout/cartesian, with get and set) that vex barely uses. Its only callers are Focus:tree and Focus:reversetree in src/core/focus.lua, which use optic.chain(optic.ipairs(), optic.traverse(children)):get(tasks) as a cycle-safe depth-first walk over linked tasks. Nothing calls Optic:set, iso, fanout, cartesian or the folds. Either replace those two calls with a small traversal helper (in focus.lua or src/lib/func.lua) and delete lib.optic and its spec, or move lib.optic out into its own package and depend on it. Keep the tree/reversetree behaviour (including cycle safety) covered by focus_spec before removing it. Once done: drop the optic.traverse mention from CLAUDE.md's 'Where code goes', and close stop-optic-set-swallowing-1 as no longer relevant.",
    vexid = "retire-lib-optic-vex-1",
    vextype = "task"
  },
  review-pretty-printing-1 = {
    created = 1783721253,
    description = "Review pretty printing",
    modified = 1792203107,
    status = "todo",
    vexbody = "",
    vexid = "review-pretty-printing-1",
    vextype = "task"
  },
  show-traceback-internal-errors-1 = {
    created = 1792069506,
    description = "Show traceback in internal errors",
    modified = 1792203107,
    status = "done",
    vexbody = "Found by the new cli unit test. `CLI:call` (`src/lib/cli.lua`) builds the `bug` error's trace with `debug.traceback(nil, 2)`, which returns nil in LuaJIT and Lua 5.1 (a nil message means no traceback is produced). So every \"Internal error\" is printed without its traceback, which hides where the crash happened. Passing a string message (e.g. `debug.traceback(\"\", 2)`) fixes it.",
    vexid = "show-traceback-internal-errors-1",
    vextype = "task"
  },
  split-comma-separated-select-1 = {
    created = 1792203108,
    description = "Split comma-separated select fields into separate fields",
    modified = 1792203128,
    status = "todo",
    vexbody = "`vex focus all --select phase,wordcount` selects a single field literally named `phase,wordcount`, so only `vexid` survives. `Focus.parse` (`src/core/focus.lua`) splits flag values on `:` only, although `Focus:select` is documented as `select comma,sep,values` and the `get` verb's example uses `--select due,id,description`. `--select phase wordcount` doesn't help either: the flag keeps only its first value, so there is currently no way to select more than one field from the CLI.",
    vexid = "split-comma-separated-select-1",
    vextype = "task"
  },
  status-resolution-ensure-there-1 = {
    created = 1779228653,
    description = "Status resolution: ensure there is a way to check which statuses are complete or not",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. StateMachine has isinitial, isinterim and isfinal; each defaults to the current state. Final means a sink: no transition to another state. Initial is the machine's initial state. Interim is neither. vex focus initial, interim and final apply these to each task's status, using the status machine of that task's own type (TaskManager:schemaof). They replace the unused, broken isdone.",
    vexid = "status-resolution-ensure-there-1",
    vextype = "task"
  },
  stop-indexing-unresolved-linked-1 = {
    created = 1792069751,
    description = "Stop indexing unresolved linked tasks",
    modified = 1792203107,
    status = "done",
    vexbody = "Found by the new e2e smoke test. After `vex resolve all` on linked tasks, `vex set <a task with dependencies> --status doing` leaves the *linked* task in the vexdex with its frontmatter as written on disk: `created`/`modified` as \"YYYY-MM-DD HH:MM:SS\" strings instead of epoch numbers. `TaskManager:readfrompath` (`src/core/task.lua`) indexes whatever `taskformat.read` returns without resolving (unformatting) it, and resolving a task reads its links through `getsingle`. Once the index holds strings, `vex view all overview` (`view.lua:183`), `vex view <id> singular` (`view.lua:221`) and `vex focus updated` (`focus.lua:42`) all crash comparing strings with numbers. Reproduced by the `test/e2e/smoke_spec.lua` fixture.\
\
Even read-only verbs trigger it: `vex view all tabular` calls `task:format` on every task, which reads each one from disk through `getsingle` and writes the raw data back to the index. After that, `vex view all overview` crashes on this repo's own backlog (`test/e2e/dogfood_spec.lua`).\
\
Fixed by unformatting on read rather than skipping the index: `TaskManager:readfrompath` runs the task through `TaskManager:unformat` (the schema's `unapply('format')`, mirroring `TaskManager:format`) before storing and indexing it, so reads keep the index up to date with hand edits and the index only ever holds unformatted values.",
    vexid = "stop-indexing-unresolved-linked-1",
    vextype = "task"
  },
  stop-optic-get-swallowing-1 = {
    created = 1791929695,
    description = "Stop optic get swallowing errors",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. Optic:get re-raises the coroutine's error instead of returning a partial result. Optic:set has the same problem and is tracked separately.",
    vexid = "stop-optic-get-swallowing-1",
    vextype = "task"
  },
  stop-optic-set-swallowing-1 = {
    created = 1792016374,
    description = "Stop optic set swallowing",
    modified = 1792203107,
    status = "todo",
    vexbody = "Same issue as [[stop-optic-get-swallowing-1]], in `Optic:set` (`src/lib/optic.lua`): it ignores the `ok` from `coroutine.resume` and returns the error message as if it were the result. It should re-raise with `error(result, 0)`. Needs a test in `test/unit/lib/optic_spec.lua`.",
    vexid = "stop-optic-set-swallowing-1",
    vextype = "task"
  },
  stop-resolve-normalising-twice-1 = {
    created = 1792016374,
    description = "Stop resolve normalising twice",
    modified = 1792203107,
    status = "todo",
    vexbody = "`normalise` in `src/core/task.lua` calls `vextype.schema.prevalidate(vextype.schema, task, context)` once unprotected, then again inside `pcall`. Every prevalidate step runs twice per resolve. Any error in the first call escapes as a `bug` instead of `resolution-failed-normalisation`. Drop the first call.",
    vexid = "stop-resolve-normalising-twice-1",
    vextype = "task"
  },
  support-comma-list-flags-1 = {
    created = 1792016373,
    description = "Support comma list flags for multi-value fields",
    modified = 1792203107,
    status = "todo",
    vexbody = "Split out of [[implement-cli-list-fields-1]]. `children`, `dependencies` and `options` are `schema.vec` fields, but a CLI flag value is always a plain string, so `vex add/set ... --dependencies a,b` fails resolution (\"Instance is not a table so also not a vec\"). One option: have `vec` prevalidate split a comma-delimited string into a list, so the field schema does the normalising.\
\
This applies to any multi-value field, not only today's `vec` fields: any field whose schema expects a list (including custom fields from `.vex/tasks`) should accept a comma-delimited flag value.",
    vexid = "support-comma-list-flags-1",
    vextype = "task"
  },
  track-vex-tmp-folder-1 = {
    created = 1791929695,
    description = "Track vex tmp folder in git",
    modified = 1792203107,
    status = "done",
    vexbody = "Fixed. .vex/tmp is now tracked through .vex/tmp/.gitignore, which ignores everything else in the folder.",
    vexid = "track-vex-tmp-folder-1",
    vextype = "task"
  },
  version-01-1 = {
    children = {},
    created = 1781730352,
    description = "Version 0.1",
    modified = 1792203107,
    status = "todo",
    vexbody = "",
    vexid = "version-01-1",
    vextype = "abstract"
  },
  when-printing-focuses-pretty-1 = {
    created = 1783721555,
    description = "When printing focuses, pretty print it",
    modified = 1792203107,
    status = "todo",
    vexbody = "",
    vexid = "when-printing-focuses-pretty-1",
    vextype = "task"
  },
  when-printing-validation-errors-1 = {
    created = 1783721568,
    description = "When printing validation errors, pretty print them",
    modified = 1792203107,
    status = "todo",
    vexbody = "",
    vexid = "when-printing-validation-errors-1",
    vextype = "task"
  }
}	