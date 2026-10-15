---
vexid: support-comma-list-flags-1
vextype: task
description: Support comma list flags for multi-value fields
created: "2026-10-14 22:19:33"
modified: "2026-10-15 09:32:45"
status: todo
---
Split out of [[implement-cli-list-fields-1]]. `children`, `dependencies` and `options` are `schema.vec` fields, but a CLI flag value is always a plain string, so `vex add/set ... --dependencies a,b` fails resolution ("Instance is not a table so also not a vec"). One option: have `vec` prevalidate split a comma-delimited string into a list, so the field schema does the normalising.

This applies to any multi-value field, not only today's `vec` fields: any field whose schema expects a list (including custom fields from `.vex/tasks`) should accept a comma-delimited flag value.