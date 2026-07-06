---
vexid: implement-cli-list-fields-1
vextype: task
description: Support list-typed fields as CLI flags
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`children`, `dependencies`, and `options` are all `schema.vec` fields, but a CLI flag value from `lib.cli`'s `Arguments:flags()` is always a plain string. Since `vec`'s validate requires an actual table, `vex add/set ... --dependencies some-task` currently fails resolution instead of creating a link. Found while writing the CLI reference and Frontmatter schema wiki pages, which currently have to tell people to edit the YAML list by hand instead. Needs some parsing convention (repeated flags? colon or comma separated?) that turns a flag value into a list before validation runs.
