---
vexid: allow-splatting-focus-other-1
vextype: atom
description: Allow splatting a focus into other operations
created: "2026-10-29 22:31:16"
modified: "2026-10-29 22:31:16"
status: todo
---

Let a saved focus feed its vexids into a list field of another command, so a query result can become links without typing the vexids:

```console
$ vex focus my-abstract-1 --tree --filter vextype:atom
$ vex set my-final-task-1 --splat --dependencies
```

`--splat` is a modifier written before a list field, like `--insert` / `--remove`. It supersedes [[allow-usage-focuses-list-type-1]].

Design and implications:

- **Snapshot, not lazy.** The vexids are read from the saved focus (`prev`) when the command runs and stored as plain links. The task does not stay tied to the focus.
- **Explicit target.** `set` must be given a target focus when splatting. Without one, target and source are both `prev` and every task would link to itself.
- **Self links and cycles.** The example's `--tree` includes `my-abstract-1` itself, and a source containing the target gives a self link or a dependency cycle. Existing resolution already rejects both, so the error comes from validation; do not silently drop the target.
- **Several targets.** Every task in the target focus gets the same list.
- **Empty source.** Plain `--splat` would clear the field; with `--insert` it is a no-op. Decide whether an empty plain splat should fail.
- **Wrong field kind.** Splatting several vexids into a single-valued field, or one that is not a `vexlink` list, fails. Add a named error (e.g. `bad-splat`) in `src/core/errors.lua` rather than leaking a schema failure.
- **Composing with `--insert` / `--remove`.** `Arguments:modifiers` (`src/lib/cli.lua`) keeps one modifier per field and `listmodifiers` in `src/core/task.lua` applies one, so `--insert --splat --dependencies` (add the focus to the existing dependencies) needs a list of modifiers per field.
- **Where the code goes.** Turning the saved focus into vexids belongs to `Focus`, applying it to `TaskManager:set`, parsing to `cli.lua`. `verbs.lua` stays thin.
- **Scope.** First version is `vex set` (anything through `TaskManager:set`). Splatting into focus operations (e.g. a `--filter` or `--union` value) is a follow-up; a saved focus would have to store the resolved vexids, since `Focus:write` overwrites `prev` and replaying would otherwise read a different focus.

Verify: e2e test that the example sets the dependencies to the atoms under the abstract, plus the self link, empty, single-valued and multiple-target cases; a unit test for the modifier in `test/unit/core/task_spec.lua`; the new error registered in `errors_spec`; documented in [[01 CLI reference]].
