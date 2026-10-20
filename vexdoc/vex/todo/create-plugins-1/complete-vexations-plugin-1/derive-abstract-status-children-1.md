---
vexid: derive-abstract-status-children-1
vextype: atom
description: Derive an abstract status from its children
created: "2026-10-19 20:55:58"
modified: "2026-10-19 20:55:58"
status: todo
---

The design journal ([[Vex]], "Fields") wants "is the abstract done" as a derived field that resolve stamps into place. Derive an abstract's `status` from its `children`: `done` when every child is in its `final` phase, `doing` when any child has started, `todo` otherwise. Resolution already arranges a task's forward links, so a child changing status also needs to re-resolve its parent (through backlinks). Decide whether a hand-set status on an abstract is still allowed.
