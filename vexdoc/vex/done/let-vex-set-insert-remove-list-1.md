---
vexid: let-vex-set-insert-remove-list-1
vextype: task
description: Let vex set insert and remove list values
created: "2026-10-17 21:13:09"
modified: "2026-10-17 21:13:09"
status: done
---
`vex set` could only overwrite a field. List fields (`children`, `dependencies`, `options`, custom `vec` fields) need values added or removed without retyping the rest. `vex set <focus> --insert --children a,b` adds each value not already in the list; `vex set <focus> --remove --children a` removes values by value. A valueless flag directly before another flag modifies it (`Arguments:modifiers()` in `src/lib/cli.lua`); `TaskManager:set` takes those modifiers and throws `unknown-modifier` for any name other than `insert`/`remove`.
