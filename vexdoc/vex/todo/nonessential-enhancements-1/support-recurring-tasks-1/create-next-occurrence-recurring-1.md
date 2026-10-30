---
vexid: create-next-occurrence-recurring-1
vextype: atom
description: Create the next occurrence when a recurring task is done
created: "2026-10-19 21:29:42"
dependencies: 
  - "[[let-task-types-register-hooks-1]]"
modified: "2026-10-30 03:17:28"
status: todo
---

We want recurring tasks. What is known so far:

- The next occurrence is kicked off when the previous task reaches its recurrence point, e.g. when it is completed.
- Recurrences are recipes, not a field on a task ([[04 Configuring recipes]]).
- It should be implemented through hooks ([[06 Configuring event hooks]]), possibly type-level ones ([[let-task-types-register-hooks-1]]).

Everything else is undecided: design it, and bring the design up for discussion before building.
