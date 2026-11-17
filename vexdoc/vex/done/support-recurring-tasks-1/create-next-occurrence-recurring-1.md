---
vexid: create-next-occurrence-recurring-1
vextype: atom
description: Create the next occurrence when a recurring task is done
created: "2026-10-19 21:29:42"
modified: "2026-11-07 11:27:25"
status: done
parent: "[[support-recurring-tasks-1]]"
---

We want recurring tasks. What is known so far:

- The next occurrence is kicked off when the previous task reaches its recurrence point, e.g. when it is completed.
- Recurrences are recipes, not a field on a task ([[04 Configuring recipes]]).
- It should be implemented through hooks ([[06 Configuring event hooks]]), possibly type-level ones ([[let-task-types-register-hooks-1]]).

Everything else is undecided: design it, and bring the design up for discussion before building.

Built on the global event system rather than type-level hooks: a recurrence is two optional `basetask` fields, `recur` and `over`, and a `post-task-resolve` hook (handle `recur`, `src/core/taskdefinitions.lua`) adds the next task when the task moves into its final phase against its previously indexed version, now the event's third arg. The `recurring` recipe (`vex recipe recurring Wash the dishes --start today --recur weekly --over due`) fills those fields in, inside an abstract under vexations, and each next task joins the same parent. [[let-task-types-register-hooks-1]] stays open for per-type hooks in general.
