---
vexid: fix-show-printing-list-fields-1
vextype: atom
description: Fix show printing list fields as table addresses
created: "2026-10-30 00:54:41"
modified: "2026-10-30 00:54:41"
status: todo
---
vex show prints a list field such as children or dependencies as "table: 0x..." (Task:show in src/core/task.lua calls tostring on the value). It should print the list, as the task file does. Verify: an e2e test in test/e2e/lifecycle_spec.lua that shows a task with dependencies.