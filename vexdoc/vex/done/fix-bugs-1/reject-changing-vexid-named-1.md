---
vexid: reject-changing-vexid-named-1
vextype: atom
description: Reject changing a vexid with a named error
created: "2026-10-19 09:21:47"
modified: "2026-10-30 01:33:49"
status: done
---

`vex set <vexid> --vexid other-1` hit an `assert` in `TaskManager:set` and printed an `Internal error`. It now throws the named `immutable-vexid` error ([[02 Frontmatter schema]]: the vexid can't be changed).
