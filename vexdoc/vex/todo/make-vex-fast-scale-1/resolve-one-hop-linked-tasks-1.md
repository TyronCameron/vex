---
vexid: resolve-one-hop-linked-tasks-1
vextype: atom
description: Resolve only one hop of linked tasks
created: "2026-10-31 05:55:58"
modified: "2026-10-31 05:56:04"
status: todo
---
TaskManager:resolveall (src/core/task.lua) queues the links of every task it resolves, not just of the tasks it was asked for, so a change to one linked task re-resolves and rewrites every task in its connected component. CLAUDE.md promises one hop: 'every task linked to it or from it'. With dependencies plus an abstract tree, every task in a project is in one component: in a 10k-task shape (test/bench/run.lua at VEX_BENCH_TASKS=10000) every atom reaches all 10,000 tasks. At 1.45k tasks, vex set on a hub atom resolved 1,120 tasks (about 6-10s); one hop resolves its 558 neighbours. Creating tasks with vex add is therefore quadratic: 200 linked tasks take 3 minutes, so the CI benchmark is held at 300 tasks. Verify: a test that a set on a task in a chain a -> b -> c resolves b but not c (count pre-task-resolve events), and just bench timings drop.