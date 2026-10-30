---
vexid: let-task-types-define-own-1
vextype: atom
description: Let task types define their own statuses as subtypes of todo doing and done
created: "2026-10-19 20:55:58"
modified: "2026-10-30 03:20:23"
status: done
---

The design journal ([[Vex]], "Statuses") says users can create new statuses for their tasks, as subtypes of `todo`, `doing` and `done`. Today the status machine is fixed in the base `task` schema (`src/core/taskdefinitions.lua`). A custom type can only replace the whole `status` field, and the `phase` transient then reads its own states.

Let a type extend the machine instead, e.g. adding `blocked` between `todo` and `doing`, or `in-review` after `doing`, while each new state still maps to a phase. Document how in [[03 Configuring task types]], and cover it with an extension in `test/e2e/extensions_spec.lua`. Coordinate with [[make-statusmachine-default-todo-1]], which shrinks the default machine.

**Bring this up for discussion before building.** A new task type that overrides the whole `status` field already works, and is an acceptable answer. Only build something here if a sleeker way turns up, and present it first.

Resolved: `basetask` defines no `status`, so a type extending it declares its own `status` field and the `phase` transient reads that machine. Overriding the whole field is the accepted answer above.