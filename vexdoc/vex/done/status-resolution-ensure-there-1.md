---
vexid: status-resolution-ensure-there-1
vextype: task
description: "Status resolution: ensure there is a way to check which statuses are complete or not"
created: "2026-05-19 22:10:53"
modified: "2026-10-14 22:19:11"
status: done
---
Fixed. StateMachine has isinitial, isinterim and isfinal; each defaults to the current state. Final means a sink: no transition to another state. Initial is the machine's initial state. Interim is neither. vex focus initial, interim and final apply these to each task's status, using the status machine of that task's own type (TaskManager:schemaof). They replace the unused, broken isdone.