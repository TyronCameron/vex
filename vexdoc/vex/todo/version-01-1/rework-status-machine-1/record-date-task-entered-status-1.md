---
vexid: record-date-task-entered-status-1
vextype: atom
description: Record the date each task entered each status
created: "2026-10-19 20:55:58"
modified: "2026-10-19 20:55:58"
status: todo
---

The design journal ([[Vex]], "Schedules") lists status dates among the dates a task should carry. Nothing records when a task moved into `doing` or `done`: `modified` changes on every touch. Record the time of each status change, e.g. a `statusdates` map derived in the status schema's `postvalidate` when the status differs from `context.previous.status`. Throughput, cycle time and the `overview` view's "Movement" section could then use it. Check that `vex resolve all` keeps the recorded dates rather than resetting them.
