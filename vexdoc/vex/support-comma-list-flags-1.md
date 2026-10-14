---
vexid: support-comma-list-flags-1
vextype: task
description: Support comma list flags for vec fields
created: "2026-10-14 22:19:33"
modified: "2026-10-14 22:19:33"
status: todo
---
Split out of [[implement-cli-list-fields-1]]. `children`, `dependencies` and `options` are `schema.vec` fields, but a CLI flag value is always a plain string, so `vex add/set ... --dependencies a,b` fails resolution ("Instance is not a table so also not a vec"). One option: have `vec` prevalidate split a comma-delimited string into a list, so the field schema does the normalising.