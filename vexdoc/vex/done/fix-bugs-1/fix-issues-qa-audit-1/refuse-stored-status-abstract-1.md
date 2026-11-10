---
vexid: refuse-stored-status-abstract-1
vextype: atom
description: Refuse a stored status on an abstract
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
`vex recipe abstract X --status todo` (the help example) stored `status` in the abstract's file, freezing its derived status. The abstract schema now has `status = schema.none`, and schemas read only stored fields (`rawget` in `Schema:iterate` and `Context:descend`), so a transient never reaches validation. See [[06 Status and state machines]].