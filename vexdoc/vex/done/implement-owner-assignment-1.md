---
vexid: implement-owner-assignment-1
vextype: task
description: "Make owner a real, validated field"
created: "2026-07-06 12:00:00"
modified: "2026-10-14 22:15:20"
status: done
---
Fixed. owner is an optional field on the base task type: schema.maybe {schema.any(config.users)}. List the allowed owners under users in .vex/config.lua (vex init writes users = {}). With no users configured, every owner is rejected; to make that work, schema.any over an empty list now matches nothing.