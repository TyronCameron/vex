---
vexid: reword-errors-leak-internals-1
vextype: atom
description: Reword errors that leak internals
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
Messages such as `Range: 3 <= 0 <= inf`, `Any schema is empty`, `Cannot find X in the task manager` and hints pointing at `config.lua` for task types are rewritten in plain words, pointing at `.vex/tasks`, `.vex/recipes` and `.vex/views`. An unknown focus suggests close vexids.