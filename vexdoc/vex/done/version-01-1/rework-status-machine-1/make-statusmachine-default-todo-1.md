---
vexid: make-statusmachine-default-todo-1
vextype: atom
description: Make statusmachine by default only have todo and done
created: "2026-10-19 07:43:12"
modified: "2026-10-30 05:34:47"
status: done
---

Needs more thinking (some maths) before changing anything.

- A status machine is a terminal directed graph. It needs an initial state, and final states with no outward arrows.
- So the minimal non-trivial machine is `todo` → `done`: everything is either not started or done. In many ways this is the most beautiful version, and it suits atoms.
- But abstracts naturally have `todo`, `doing` and `done`: some of their children have started and some haven't.
- The `phase` transient (`initial`, `interim`, `final`) also lines up with three states.

The leaning is still `todo`/`done` for the default, but it is less clear for the types above atoms. Work out whether a type's machine, or its phases, should differ by where the type sits in the tree, and how [[let-task-types-define-own-1]] fits in.
