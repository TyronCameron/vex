---
vexid: create-next-occurrence-recurring-1
vextype: atom
description: Create the next occurrence when a recurring task is done
created: "2026-10-19 21:29:42"
dependencies: 
  - "[[let-task-types-register-hooks-1]]"
  - "[[fire-event-task-status-changes-1]]"
  - "[[add-recur-field-reads-phrases-1]]"
modified: "2026-10-19 21:29:43"
status: todo
---

When a task with `recur` reaches its `final` phase, create its next occurrence. Use the status-change event ([[fire-event-task-status-changes-1]]) and a type-level hook ([[let-task-types-register-hooks-1]]) on the base `task` type, so it works for every type:

- The new task copies the description, type, owner, cost, benefit, body, `recur` and parent (it is inserted into the same abstract's `children`). It gets a fresh vexid from the tagger's counter, status `todo`, and `due` advanced with `naturaltime.next(recur, previous due or completion time)`.
- The finished task stays as a record. Optionally, link the two (`previous: [[vexid]]`) so a series can be followed with `--tree previous`.
- `vex add`/`set` print the new vexid, and the focus moves to it.
- Edge cases to settle and test: completing a task late (skip missed occurrences or not), removing `recur` to end a series, and `vex resolve all` never creating duplicates.

Document recurring tasks in [[01 CLI reference]] and [[02 Creating your first task using vex]], and add an e2e test that completes a weekly task and finds the next one due a week later.
