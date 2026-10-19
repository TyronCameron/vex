---
vexid: fire-event-task-status-changes-1
vextype: atom
description: Fire an event when a task status changes
created: "2026-10-19 21:29:42"
modified: "2026-10-19 21:29:42"
status: todo
---

Today "a task was completed" can only be detected by comparing `context.previous.status` inside a schema, or by re-reading the task in a `post-task-resolve` hook, which has no old status. Fire a `pre-`/`post-task-status` pair from `TaskManager:resolve` when the resolved status differs from the indexed one, with `(vexid, from, to)`, and its `phase` before and after. Then "on done" and "on start" hooks are one line (`event:on 'post-task-status' (function(vexid, from, to) ... end)`). Add it to the events table in [[06 Configuring event hooks]], and test that it fires once per real change and not on a plain re-resolve.
