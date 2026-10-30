A task's `status` is `todo` or `done`, and only `todo` can move to `done`:

```console
$ vex set tidy-readme-1 --status done
$ vex set tidy-readme-1 --status todo
ERROR: Cannot transition status from done to todo
...
```

Setting a task to its current status is fine, and `doing` is not a status: `vex set --status doing` fails with `Cannot transition status from todo to doing`.

## Abstracts

An abstract stores no status. It is worked out from its children each time it is read, so you never set it:

| Children | `status` |
| --- | --- |
| All `todo` (or none) | `todo` |
| All `done` | `done` |
| Some of each | `doing` |

To close an abstract, finish its children ([[05 Getting into focus#Close off an abstract]]).

## Phases

The `phase` transient says where a status sits in its machine, whatever the status is called:

| Phase | Meaning | Tasks |
| --- | --- | --- |
| `initial` | The first status. | `todo`, and abstracts whose children are all `todo`. |
| `interim` | Anywhere between. | Abstracts with `doing` status. |
| `final` | No way out. | `done`, and abstracts whose children are all `done`. |

The named focuses `initial`, `interim` and `final` select by phase, and `ready` means "not `final`, with no unfinished `dependencies`". "Open" means not `final`: `--notin final`.
