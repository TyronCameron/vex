A task's `status` moves through a state machine. Every built-in type uses the same one:

| From | To |
| --- | --- |
| `todo` | `doing` |
| `doing` | `done` |
| `done` | nothing |

Setting a task to its current status is fine. Any other move fails resolution and leaves the task file as it was:

```console
$ vex set tidy-readme-1 --status done
ERROR: Cannot transition status from todo to done
...
$ vex set old-finished-chore-1 --status doing
ERROR: Cannot transition status from done to doing
...
```

## Phases

The `phase` transient says where a status sits in its machine, whatever the status is called:

| Phase | Meaning | Here |
| --- | --- | --- |
| `initial` | The first status. | `todo` |
| `interim` | Anywhere between. | `doing` |
| `final` | No way out. | `done` |

The named focuses `initial`, `interim` and `final` select by phase, and `ready` means "not `final`, with no unfinished `dependencies`". "Open" in vex means not `final`: `--notin final`.

## Changing many tasks

`set` applies to the whole focus, and each task must make a legal move. To finish a mixed group, step through `doing` and leave out tasks already `done`:

```console
$ vex focus ship-billing-rewrite-1 --tree children --notin final
$ vex set --status doing
$ vex set --status done
```

See [[05 Getting into focus]] for more queries.
