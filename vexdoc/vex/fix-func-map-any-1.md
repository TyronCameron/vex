---
vexid: fix-func-map-any-1
vextype: task
description: Fix func map and any helpers
created: "2026-10-13 22:14:55"
modified: "2026-10-13 22:14:55"
status: todo
---

`src/lib/func.lua` has three broken helpers:

- `func.map` writes every result to `res[1]` instead of `res[i]`, so it returns a single-element table holding the last mapped value.
- `func.any` and `func.all` name their predicate parameter `func`, which shadows the module, so `func.reduce(...)` inside them calls the predicate instead. `func.all` also tests `not func` before `f` is set up, which checks the module rather than the argument.
- `func.count` has the same `func` shadowing problem.

`func.reduce`/`func.ireduce` now exist, so `func.sum`/`func.prod` work. Once `map` and the shadowing are fixed, `any`/`all`/`count` should work too. The `decision` task type's constraint (`core/taskdefinitions.lua`) relies on `func.any`. Needs tests in `test/unit/lib/func_spec.lua` for `map`, `any`, `all` and `count` first.
