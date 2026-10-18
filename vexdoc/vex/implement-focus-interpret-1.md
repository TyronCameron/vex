---
vexid: implement-focus-interpret-1
vextype: task
description: "Implement Focus:interpret"
created: "2026-07-06 12:00:00"
modified: "2026-10-17 22:35:33"
status: done
---

`Focus:interpret()` in `core/focus.lua` currently just hard-throws ("this is a hard feature that I don't know how to do yet"). The intent is that `--interpret` before a flag would convert natural-language values (e.g. `due:tomorrow`) before matching. Needed before any doc can honestly show `--interpret` working.


Done: `--interpret` reads the next `filter` or `between` value through the field's `interpret` iso, which `date` and `datetime` define with `src/lib/naturaltime.lua`.