vex is a single LuaJIT program with no build step. This page covers working on it; [[Plugin architecture]] and [[Resolution pipeline]] explain how it fits together.

## Commands

| Command | Does |
| --- | --- |
| `./src/vex <verb>` | Runs vex from the clone. |
| `just test` | Unit tests, e2e tests and lint, reporting every failing suite. |
| `just test-unit [spec...]`, `just test-e2e [spec...]` | One layer, or only the given spec files. |
| `just lint` | `luacheck`, plus a check that every `src` module has a unit spec. |
| `just docs` | Builds this wiki into a site (needs `hugo`, `go` and `obsidian-export`). |

After cloning, pulling or switching branches, run `./src/vex resolve all`: the index is not in git, and it takes in every task file that changed.

## Tests

Every behaviour change comes with a test at the right layer, written first and seen to fail.

- **Unit** (`test/unit/**/*_spec.lua`): one module through its own API. Each `src/<path>.lua` has a `test/unit/<path>_spec.lua`. Each spec runs in its own fresh `vex init` folder; never run them from the repository root, which would touch this repo's own tasks.
- **e2e** (`test/e2e/*_spec.lua`): black box. They only run `src/vex` in a temporary project through `helper.lua`. Anything a user can type belongs here. `smoke_spec` must exercise every verb, view and focus form, and `dogfood_spec` resolves a copy of this repo's own backlog.

An `Internal error` is always a regression. A test for a known, unfixed bug names its vex task in the test name and fails until the bug is fixed.

## Where code goes

| Concern | Module |
| --- | --- |
| Which tasks? (children, parents, links) | `src/core/focus.lua` |
| Adding, setting, removing, resolving, reading, writing | `src/core/task.lua` |
| Validating, normalising, formatting values | `src/lib/schema.lua`, `src/core/taskdefinitions.lua` |
| Storage and the index | `src/core/vexdex.lua` |
| Verbs | `src/core/verbs.lua`: thin, no field names |
| Display | `src/core/view.lua` |
| User-facing errors | `src/core/errors.lua` |
| Generic helpers | `src/lib/func.lua` |

Use a module's existing machinery rather than writing a smaller copy elsewhere. Don't write explanatory comments: code should read clearly, and a comment records only a non-obvious *why*.

## The backlog

This repo's own tasks live in `vexdoc/vex`, tracked with vex itself. Raise new work with `./src/vex add`, as an `atom` (one concrete change, with a body saying what, where and how to verify) under an `abstract` that names its category. Close a task with `./src/vex set <vexid> --status done`.
