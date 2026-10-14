{
  cli-pass-raw-args-1 = {
    created = 1779228684,
    description = "CLI should pass raw args",
    modified = 1792016116,
    status = "done",
    vexbody = "Fixed. `CLI:run` now keeps the original raw string it was invoked with (before verb-name removal or tokenizing) and stashes it as `args.raw` on the parsed `Arguments` table it passes to the verb - so any verb can reach the exact, unsplit text a user typed after `vex`, alongside the already-tokenized positional/flag view. No built-in verb consumes it yet; it's there for verbs (built-in or user-defined) that want to do their own parsing. Covered by a new test in `test/unit/lib/cli_spec.lua`.",
    vexid = "cli-pass-raw-args-1",
    vextype = "task"
  },
  create-events-file-slip-1 = {
    created = 1783721405,
    description = "Create events file and slip in events architecture",
    modified = 1792016116,
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
    modified = 1792016116,
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
    modified = 1792016116,
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
    modified = 1792016116,
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
    modified = 1792016116,
    status = "todo",
    vexbody = "",
    vexid = "create-view-next-up-1",
    vextype = "task"
  },
  ensure-verbs-return-data-1 = {
    created = 1779226066,
    description = "Ensure all verbs return data and do not print",
    modified = 1792016116,
    status = "done",
    vexbody = "Fixed. Every verb (`show`, `focus`, `view`, `remove`, `get`, `recipe` in `core/verbs.lua`, plus the built-in `help` verb in `lib/cli.lua`) previously called `print`/`pretty.print` directly, mid-verb, instead of returning a value. They now build up a list of output lines and `return table.concat(lines, \"\\n\")` (via a small `join_lines` helper that returns `nil` rather than `\"\"` when there's nothing to say, so a verb that produced no output before still produces none). `CLI:run` already printed a verb's string/number return value once at the top level - that single `print` call reproduces the exact same terminal output as the old per-line `print`/`pretty.print` calls, since each of those always emitted its own trailing newline.\
\
Terminal output is unchanged (verified via the e2e suite and manual runs), but every verb is now independently callable through `CLI:call` and testable/composable without capturing stdout.",
    vexid = "ensure-verbs-return-data-1",
    vextype = "task"
  },
  fix-focus-binary-ops-cli-1 = {
    created = 1783339200,
    description = "Fix union/intersect/xor/notin/onlyin crashing from the CLI",
    modified = 1792016116,
    status = "todo",
    vexbody = "\
Confirmed by testing: `vex focus all --union all`, `--intersect all`, and (by the same code path) presumably `--xor`/`--notin`/`--onlyin` all crash with \"Internal error ... attempt to call method 'get' (a nil value)\". `Focus:union`/`Focus:intersect`/etc. (`core/focus.lua`) expect a Focus *object* as their argument (they call `focus:get(tasks)` on it), but `Focus.parse` passes whatever raw string came from the CLI flag value (e.g. `\"all\"`) straight through — never resolving it to an actual named focus first. `--complement` works fine since it takes no argument at all. Needs `Focus.parse` (or the binary-op methods themselves) to resolve a string argument through `namedfocus.focus(...)` before calling it.\
",
    vexid = "fix-focus-binary-ops-cli-1",
    vextype = "task"
  },
  fix-func-map-any-1 = {
    created = 1791929695,
    description = "Fix func map and any helpers",
    modified = 1792016116,
    status = "done",
    vexbody = "Fixed. func.map writes res[i]. count, any and all name their predicate f, so the func module is no longer shadowed. any and all are seeded with false and true, so empty tables work. count counts the values of the sparse filter result.",
    vexid = "fix-func-map-any-1",
    vextype = "task"
  },
  fix-init-requires-existing-vex-1 = {
    created = 1783339200,
    description = "Fix vex init crashing outside an existing .vex tree",
    modified = 1792016116,
    status = "done",
    vexbody = "Fixed. src/vex.lua already skips loading plugins for init, so vex init works in a fresh directory with no .vex above it (checked by hand).",
    vexid = "fix-init-requires-existing-vex-1",
    vextype = "task"
  },
  fix-list-field-roundtrip-1 = {
    created = 1783339200,
    description = "List-typed fields never survive a disk round-trip",
    modified = 1792016116,
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
    modified = 1792016116,
    status = "done",
    vexbody = "Fixed. lux.toml now runs src/vex.lua, the real entry point.",
    vexid = "fix-lux-entry-point-1",
    vextype = "task"
  },
  fix-status-transition-enforcement-1 = {
    created = 1783339200,
    description = "Status state machine doesn't actually reject invalid transitions",
    modified = 1792016116,
    status = "done",
    vexbody = "\
Fixed. The `statemachine` schema (`core/taskdefinitions.lua`) used to cache one machine on `self.extra`, shared by every task, and seed it from `context.task.status`, which `TaskManager:set` had already overwritten. Now `set` builds a new task instead of changing the indexed one, `resolve` passes the indexed version as `context.previous`, and `prevalidate` builds a fresh `statemachine.new` from that previous status. `todo -> done` and `doing -> todo` now fail with `resolution-failed-validation`. An unchanged status is always valid, so `vex resolve all` accepts whatever is on disk, and a new task with no status gets `todo`. `lib/statemachine.lua`'s `preprocess` copies state definitions instead of mutating them, so a machine can be built more than once from the same definition. `version-01-1` got `children: []` so `vex resolve all` completes. Covered by `test/unit/core/taskdefinitions_spec.lua`, `test/unit/core/task_spec.lua` and an e2e test in `test/e2e/lifecycle_spec.lua`.\
",
    vexid = "fix-status-transition-enforcement-1",
    vextype = "task"
  },
  fix-typed-field-cli-input-1 = {
    created = 1783339200,
    description = "Fix numeric and datetime fields failing validation from the CLI",
    modified = 1792016116,
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
  implement-categorical-variables-1 = {
    created = 1783721588,
    description = "Implement categorical variables",
    modified = 1792016116,
    status = "done",
    vexbody = "Closed: no new machinery needed. A categorical variable is schema.any over constants, e.g. schema.any {'low', 'medium', 'high'}; covered by a test in schema_spec.lua. The owner field is the first one that uses it.",
    vexid = "implement-categorical-variables-1",
    vextype = "task"
  },
  implement-cli-list-fields-1 = {
    created = 1783339200,
    description = "Support list-typed fields as CLI flags",
    modified = 1792016163,
    status = "done",
    vexbody = "Fixed for focuses: vex focus a,b,c works. from_comma_sep called a function that doesn't exist, and is now saved under its own name, so the prev focus replays it. Comma-separated list flags like --dependencies a,b are split out into their own task.",
    vexid = "implement-cli-list-fields-1",
    vextype = "task"
  },
  implement-config-defaults-1 = {
    created = 1783339200,
    description = "Wire up config.lua's default.* and plugins.* keys",
    modified = 1792016116,
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
    modified = 1792016116,
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
    modified = 1792016116,
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
    modified = 1792016116,
    status = "todo",
    vexbody = "\
`.vex/focuses` is created by `vex init` but nothing reads it — only the 4 hardcoded named focuses in `core/focus.lua` (all, none, updated, prev) exist. Auto-register a Lua file per named focus, following the same shape as `Focus.register_focus`.\
",
    vexid = "implement-focus-loader-1",
    vextype = "task"
  },
  implement-inline-plugin-1 = {
    created = 1783339200,
    description = "Build the inline mode plugin",
    modified = 1792016116,
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
    modified = 1792016120,
    status = "done",
    vexbody = "Fixed. owner is an optional field on the base task type: schema.maybe {schema.any(config.users)}. List the allowed owners under users in .vex/config.lua (vex init writes users = {}). With no users configured, every owner is rejected; to make that work, schema.any over an empty list now matches nothing.",
    vexid = "implement-owner-assignment-1",
    vextype = "task"
  },
  implement-priorityorder-variables-1 = {
    created = 1783721600,
    description = "Implement priority/order variables",
    modified = 1792016116,
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
    modified = 1792016116,
    status = "todo",
    vexbody = "\
`.vex/recipes` is created by `vex init` but nothing reads it — the only recipe that exists (`abstract`) is registered directly in `core/taskdefinitions.lua`. Auto-register a recipe per file, following the `{ add = function(task, taskproperties) ... end }` shape `Recipe:recipe` already expects.\
",
    vexid = "implement-recipe-loader-1",
    vextype = "task"
  },
  implement-task-type-loader-1 = {
    created = 1783339200,
    description = "Load custom task types from .vex/tasks",
    modified = 1792016213,
    status = "done",
    vexbody = "Fixed. The new core/extensions.lua runs every .lua file in .vex/tasks with task and schema in scope (via setfenv), so a file just calls task:task 'bug':extends 'task' { schema = ... }. Files load in path order, so a parent type must sort before its children. A broken file throws bad-extension.",
    vexid = "implement-task-type-loader-1",
    vextype = "task"
  },
  implement-vexations-plugin-1 = {
    created = 1783339200,
    description = "Build the vexations plugin",
    modified = 1792016116,
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
    modified = 1792016116,
    status = "todo",
    vexbody = "\
`.vex/views` is created by `vex init` but nothing reads it — the 6 built-in views (csv, tabular, json, kanban, overview, singular) are only registered in `core/view.lua`. Auto-register a view per file using the `{ display = function(focus, flags) ... end }` shape `View:view` already expects.\
",
    vexid = "implement-view-loader-1",
    vextype = "task"
  },
  make-claude-review-docs-1 = {
    created = 1783721651,
    description = "Make claude review docs",
    modified = 1792016116,
    status = "todo",
    vexbody = "Make claude review the docs. It wrote a stack of \"not done\" and \"this is actually implemented right now\" in the code ... that's dumb, I don't want any of that in the docs. The docs should read as fact. ",
    vexid = "make-claude-review-docs-1",
    vextype = "task"
  },
  make-cli-understand-quoting-1 = {
    created = 1783721534,
    description = "make CLI understand quoting",
    modified = 1792016116,
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
    modified = 1792016116,
    status = "todo",
    vexbody = "",
    vexid = "make-config-actually-control-1",
    vextype = "task"
  },
  put-normalise-validate-derive-1 = {
    created = 1779449388,
    description = "Put normalise, validate, and derive into lib.schema",
    modified = 1792016116,
    status = "done",
    vexbody = "",
    vexid = "put-normalise-validate-derive-1",
    vextype = "task"
  },
  review-pretty-printing-1 = {
    created = 1783721253,
    description = "Review pretty printing",
    modified = 1792016116,
    status = "todo",
    vexbody = "",
    vexid = "review-pretty-printing-1",
    vextype = "task"
  },
  status-resolution-ensure-there-1 = {
    created = 1779228653,
    description = "Status resolution: ensure there is a way to check which statuses are complete or not",
    modified = 1792016116,
    status = "todo",
    vexbody = "",
    vexid = "status-resolution-ensure-there-1",
    vextype = "task"
  },
  stop-optic-get-swallowing-1 = {
    created = 1791929695,
    description = "Stop optic get swallowing errors",
    modified = 1792016116,
    status = "done",
    vexbody = "Fixed. Optic:get re-raises the coroutine's error instead of returning a partial result. Optic:set has the same problem and is tracked separately.",
    vexid = "stop-optic-get-swallowing-1",
    vextype = "task"
  },
  track-vex-tmp-folder-1 = {
    created = 1791929695,
    description = "Track vex tmp folder in git",
    modified = 1792016116,
    status = "done",
    vexbody = "Fixed. .vex/tmp is now tracked through .vex/tmp/.gitignore, which ignores everything else in the folder.",
    vexid = "track-vex-tmp-folder-1",
    vextype = "task"
  },
  version-01-1 = {
    children = {},
    created = 1781730352,
    description = "Version 0.1",
    modified = 1792016116,
    status = "todo",
    vexbody = "",
    vexid = "version-01-1",
    vextype = "abstract"
  },
  when-printing-focuses-pretty-1 = {
    created = 1783721555,
    description = "When printing focuses, pretty print it",
    modified = 1792016116,
    status = "todo",
    vexbody = "",
    vexid = "when-printing-focuses-pretty-1",
    vextype = "task"
  },
  when-printing-validation-errors-1 = {
    created = 1783721568,
    description = "When printing validation errors, pretty print them",
    modified = 1792016116,
    status = "todo",
    vexbody = "",
    vexid = "when-printing-validation-errors-1",
    vextype = "task"
  }
}	