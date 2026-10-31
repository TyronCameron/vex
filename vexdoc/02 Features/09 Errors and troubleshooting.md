Every user mistake fails with a named error, a message and a hint, and exits non-zero. `Internal error` is the exception: that is a bug in vex, so please report it.

## Errors

| Error | Cause | Fix |
| --- | --- | --- |
| `not-vexed` | No `.vex` folder in the current folder or above it. | `vex init`, or `cd` into your project. |
| `already-vexed` | `vex init` where a `.vex` already exists. | Nothing to do. |
| `no-focus` | A command needed the saved focus and there is none, or it can't be replayed. | `vex focus <name>` or `vex add` to set one. |
| `unknown-focus` | The focus is not a named focus, a vexid in the index or a path. | Check the spelling. If the task exists on disk, `vex resolve all`. |
| `unknown-focus-operation` | A flag that isn't a focus operation, such as `--colour`. | See [[05 Getting into focus]]. |
| `not-a-date-field` | `vex view <focus> ics --by <field>` where the field isn't a `date` or `datetime`. | Pick one, such as `due` or `created`. |
| `uninterpretable` | A time phrase in a focus (`--between due:someday:now`) that vex can't read. A bad `--due` on `add` or `set` is a normalisation failure instead. | Use a phrase from [[01 CLI reference#Interpreting times]]. |
| `unknown-vextype` | `--vextype` names a type that isn't registered. | Use `task`, `abstract`, `decision`, `exploration`, `atom` or one from `.vex/tasks`. |
| `unknown-view`, `unknown-recipe` | No such view or recipe. | `vex view` and `vex recipe` list them. |
| `unknown-modifier` | `--insert` or `--remove` before something that isn't a list field. | `vex set x --insert --children a,b`. |
| `immutable-vexid` | `vex set --vexid`. | A vexid is the task's identity: add a new task and remove the old one. |
| `task-creation-failed` | A description of 3 characters or fewer. | Describe the task in at least two words. |
| `task-already-exists`, `path-already-exists` | The new vexid or file path is taken. | Reword the description, or `vex resolve all` if the file isn't indexed. |
| `resolution-failed-normalisation`, `-validation`, `-derivation` | A field is invalid. The message names the field, and the footer links the file. | Fix the value, or the file if you edited it by hand. The task stays as it was. |
| `multiple-parents` | A task is in two abstracts' `children`. | Remove it from one. |
| `self-child` | A task is in its own `children`. | Remove it. |
| `dependency-cycle` | Dependencies that lead back to the task. | Remove one of them. |
| `dependency-with-children` | A dependency on an abstract or a decision. | Depend on the atoms under it. |
| `duplicate-vexid` | Two files hold the same `vexid`, usually a copied task file. | Keep one. Nothing was changed. |
| `bad-groupby` | `paths.groupby` isn't a list of field names. | `groupby = {'lineage', 'status'}`. |
| `move-failed` | A task file couldn't be moved to its folder. | Check the folder is writable. |
| `bad-extension` | A file in `.vex` (or the global folder) fails to load. | Fix or remove the file named. |
| `hook-failed` | A hook in `.vex/events` raised an error. | Fix the hook ([[06 Configuring event hooks]]). |

## Troubleshooting

**My focus is empty.** A focus is run again each time it is used, so it shrinks as tasks change ([[05 Getting into focus#It is a recipe, not a list]]). Print it with `vex focus`, then check each step. A `--filter` compares exactly, so `status:Done` matches nothing.

**vex doesn't see a file I added or edited.** The index only knows what vex has resolved. Run `vex resolve all` (or `vex resolve <vexid>`).

**`set` was rejected.** The message says which field and why; the file is left as it was. The usual causes: a status that goes backwards ([[06 Status and state machines]]), a `children` or `dependencies` entry that breaks the rules above, an `owner` missing from `taskowners`.

**A file is in the wrong folder.** Run `vex resolve all`. With `paths.groupby`, vex owns the layout and moves files back.

**Everything is wrong after a pull.** `vex resolve all` ([[07 Working with git and a team]]).
