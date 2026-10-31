---
vexid: skip-rewriting-unchanged-linked-1
vextype: atom
description: Skip rewriting unchanged linked tasks
created: "2026-10-31 05:55:58"
dependencies: 
  - "[[resolve-one-hop-linked-tasks-1]]"
modified: "2026-10-31 06:40:29"
status: done
---
resolveall writes every linked task it reached, even when resolving left its stored fields unchanged: after vex set on a hub atom at 1.45k tasks, all 1,120 rewritten files were byte-identical. Writing (and resolving) only the linked tasks whose stored fields change would bring a densely linked set down to the cost of an unlinked one (0.14s at 1.45k tasks, 0.49s at 10k). Verify with [[resolve-one-hop-linked-tasks-1]]'s test plus a check that an unaffected neighbour's file mtime does not change; compare just bench.