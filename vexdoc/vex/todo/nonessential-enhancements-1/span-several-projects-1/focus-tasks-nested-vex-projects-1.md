---
vexid: focus-tasks-nested-vex-projects-1
vextype: atom
description: Focus on tasks across nested vex projects
created: "2026-10-19 20:55:58"
dependencies: 
  - "[[allow-several-task-folders-one-1]]"
modified: "2026-10-19 20:56:10"
status: todo
---

The design journal ([[Vex]], "Nesting") wants a view across projects: a `.vex` project nested inside another, or several sibling projects, queried together. Today the vexdex binds to the nearest `.vex` when it loads. Design how an outer project sees inner projects' tasks: a named focus over each inner vexdex, and namespaced vexids to avoid clashes (`inner:task-1`). Links across projects are out of scope at first.
