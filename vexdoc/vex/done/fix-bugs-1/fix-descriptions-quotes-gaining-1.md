---
vexid: fix-descriptions-quotes-gaining-1
vextype: atom
description: Fix descriptions with quotes gaining backslashes after resolve all
created: "2026-10-30 22:39:55"
modified: "2026-10-31 02:07:03"
status: done
---
A description holding a double quote, e.g. `child, "thing" here`, is stored correctly by `vex add`, but after `vex resolve all` (reading the task file back) the in-memory description has literal backslashes (`child, \"thing\" here`), so `vex view all json` shows `\\\"`. The frontmatter reader does not unescape YAML double-quoted strings. Verify: add the task, run `vex resolve all`, `vex view all json`.