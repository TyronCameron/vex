---
vexid: mark-options-decision-rejects-1
vextype: atom
description: Mark the options a decision rejects as not needed
created: "2026-10-19 20:55:58"
modified: "2026-10-19 20:55:58"
status: todo
---

The design journal ([[Vex]], "Decision") says decisions encode reachability: choosing one option collapses the branches not taken. When a decision's `decision` is set, the other `options` (and their subtrees) are no longer needed, but nothing marks them. They stay `todo` and show up in every focus. Add a way to retire them, e.g. a `dropped` final status or a derived transient such as `reachable`, and make the planned next-up view ([[create-view-next-up-1]]) skip them.
