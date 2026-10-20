---
vexid: ensure-decisions-work-fully-1
vextype: atom
description: Ensure decisions work fully
created: "2026-10-19 07:28:54"
modified: "2026-10-19 09:22:04"
status: todo
---

Check every promise the docs make about `decision` and add e2e coverage for any that lacks it: `options` is required and every option must be an existing task, `decision` must be one of `options`, it can't have `children`, and removing an option task (`vex remove`) leaves the decision valid.
