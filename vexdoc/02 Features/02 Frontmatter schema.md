Every task file's frontmatter is validated against the schema for its `vextype`, defined in `src/core/taskdefinitions.lua`. This page documents what's actually enforced today; see [[03 Vexations (task types)]] for what each `vextype` means and when to use it.

## Fields on every task

| **Property**  | **Type**              | **Description**                                                                                     |
| ------------- | ---------------------- | ------------------------------------------------------------------------------------------------------ |
| `vexid`       | text                   | The unique id, generated from the description by the tagger. Doubles as the filename. Only user-settable indirectly (by editing the description before the first resolve) — `set` refuses to change it. |
| `description` | text                   | The only field you actually have to supply. Must be more than 3 characters and at least 2 words.       |
| `vextype`     | text                   | Which task type this is. Defaults to `task` if omitted. Must be a registered type (`task`, `abstract`, `decision`, `exploration`, `atom`, or a custom one — see [[03 Configuring task types]]). |
| `status`      | text (state machine)  | Intended to be `todo → doing → done`, in that order only, with `done` terminal. Defaults to `todo`. This isn't actually enforced today — `todo` can currently be set straight to `done`, and `doing` back to `todo`, with no error. Tracked as [[fix-status-transition-enforcement-1]]. |
| `created`     | datetime              | Stamped automatically the first time a task is resolved. Not user-settable in practice — the schema always derives it from the current time. |
| `modified`    | datetime              | Re-derived on every resolve. Same caveat as `created`.                                                 |

> [!WARNING] `due` currently fails resolution unconditionally
> Setting `due` — via `--due` on `add`/`set`, *or* by hand-editing the YAML and running `vex resolve` — always fails validation today, even with a correctly-formatted value. The string is expected to convert to an epoch number before the final check, but it reaches that check still as a string. Tracked as [[fix-typed-field-cli-input-1]]. The intended format (once fixed) is `YYYY-MM-DD HH:MM:SS` on disk; there is no natural-language parsing (`tomorrow`, `next week`, etc.) despite a source comment describing it as a goal.

## Optional fields (validated, but not present on every type)

| **Property**  | **Type**                     | **Applies to**                | **Description**                                                                 |
| ------------- | ------------------------------ | -------------------------------- | ---------------------------------------------------------------------------------- |
| `vexbody`     | text                          | `task` (optional); forced empty on `abstract`/`exploration` | Free-form markdown body. Resolution rejects a non-empty body on `abstract` and `exploration` tasks. |
| `due`         | datetime                     | `task` and everything that extends it | Fails resolution unconditionally today — see the callout above.          |
| `cost`, `benefit` | number                    | `task` and everything that extends it | Plain numbers, no unit or currency semantics attached. Also fails today: a CLI flag value is always a string, and `schema.num` has no string→number coercion, so `--cost 15` fails resolution the same way `due` does ("The instance: `15` is not a number"). Tracked under the same [[fix-typed-field-cli-input-1]]. |
| `dependencies`| list of links (`vexlink`)    | `task` and everything that extends it | Each entry must be an existing task's `vexid`. Broken today, full stop — see the callout below. |
| `children`    | list of links (`vexlink`)    | `abstract`                      | The mechanism the `tree`/`reversetree`/`singular` view machinery actually walks to find parent/child relationships — see [[03 Vexations (task types)]]. Defaults to an empty list. Same breakage as `dependencies`. |
| `options`     | list of links (`vexlink`)    | `decision`                      | The candidate tasks a decision is choosing between. Required (not optional) on a `decision` task — and, per the callout below, currently impossible to populate, so `decision` tasks can't be created at all today. |
| `decision`    | link (`vexlink`)              | `decision`                      | Which `options` entry was chosen. Must be one of `options` — resolution rejects any other value. (Earlier drafts of this page called this field `choice`; the real field name is `decision`.) |

> [!WARNING] `children`, `dependencies`, and `options` don't survive being written and read back, at all
> These are all list-typed fields. A CLI flag value is always a single string, so `--dependencies some-task` can't work (tracked as [[implement-cli-list-fields-1]]) — but hand-editing the YAML list in the file doesn't work either: the default file format's reader (`src/default/obsidian.lua`) parses one `key: value` line at a time with no support for multi-line YAML lists, so a written array reads back as an empty string. Concretely: `vex add X --vextype abstract` succeeds (its `children` defaults to an empty list), but the *next* `vex resolve all` fails on that exact task, because the round-tripped `children` is now a string, not a table. Tracked as [[fix-list-field-roundtrip-1]] — until it lands, treat `abstract` and `decision` as broken across more than one resolve pass.

## Fields that are *not* schema-validated (yet)

Anything else you pass to `add`/`set`, or write into a file by hand, is stored in frontmatter as-is with no checking — vex's schemas use `schema.atleast`, which validates the fields it knows about and lets anything extra through untouched. Two worth calling out specifically because they show up elsewhere in this wiki:

- **`parent`** — despite showing up in the "overview" view's structure stats (which just count how many tasks have a nil `parent` key) and in early design notes, `parent` has no schema entry and nothing derives or checks it. The actual parent/child relationship vex's tree-walking logic uses is `children` on the *abstract*, walked in reverse — not a `parent` field on the child. Treat any `parent` you set today as a plain label, not a real link.
- **`owner`** — free-form text, "who this is for," with no validation and no built-in notion of users at all (vex has no concept of accounts). It's genuinely useful anyway: because it's just an ordinary field, `--filter owner:alice` works on it like any other field, which is the basis for the team workflow on [[Home]]. Making `owner` a real, `vexlink`-style validated field is tracked as [[implement-owner-assignment-1]] — until then, nothing stops you from misspelling a name and getting silently filtered out.

## Field format

This is the schema vex validates against; it isn't the same thing as the file format on disk. The concrete markdown-plus-YAML-frontmatter layout you'll see in `.vex` projects today is just the current default implementation of a pluggable `taskformat` slot (`src/default/obsidian.lua`) — see [[Plugin architecture]]. Nothing above depends on that choice; a different `taskformat` plugin could store the same fields in a completely different structure.
