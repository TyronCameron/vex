---
vexid: rewrite-inline-tags-carry-task-1
vextype: atom
description: Rewrite inline tags to carry their task vexid
created: "2026-10-19 09:21:53"
dependencies: 
  - "[[implement-inline-plugin-1]]"
modified: "2026-10-19 09:22:08"
status: todo
---

[[01 CLI reference#Inline tags]]: after `vex inline` creates a task for a tag, it rewrites the tag to carry the task's vexid (e.g. `#atom/retry-upload-1`), so later runs update that task instead of adding a new one. Decide the tag syntax, make the rewrite atomic like other writes, and test that a second `vex inline` run adds nothing.
