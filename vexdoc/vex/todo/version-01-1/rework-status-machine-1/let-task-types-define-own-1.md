---
vexid: let-task-types-define-own-1
vextype: atom
description: Let task types define their own statuses as subtypes of todo doing and done
created: "2026-10-19 20:55:58"
modified: "2026-10-19 20:55:58"
status: todo
---

The design journal ([[Vex]], "Statuses") says users can create new statuses for their tasks, as subtypes of `todo`, `doing` and `done`. Today the status machine is fixed in the base `task` schema (`src/core/taskdefinitions.lua`). A custom type can only replace the whole `status` field, and the `phase` transient then reads its own states.

Let a type extend the machine instead, e.g. adding `blocked` between `todo` and `doing`, or `in-review` after `doing`, while each new state still maps to a phase. Document how in [[03 Configuring task types]], and cover it with an extension in `test/e2e/extensions_spec.lua`. Coordinate with [[make-statusmachine-default-todo-1]], which shrinks the default machine.
