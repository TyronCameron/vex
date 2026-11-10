---
vexid: fix-help-examples-not-work-1
vextype: atom
description: Fix help examples that do not work
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
Help examples used a partial vexid (`vex show make-coffee`), a field that doesn't exist (`--importance`) and `--status` on an abstract recipe. `suggest` described itself as installing autocomplete. All of these now work as written.