---
vexid: fix-focusfocus-dropping-unions-1
vextype: task
description: Fix Focus.focus dropping unions
created: "2026-10-14 22:19:33"
modified: "2026-10-17 21:13:10"
status: done
---
`Focus.focus(...)` in `src/core/focus.lua` calls `focus:union(namedfocus.focus(focusname))` for every name after the first and throws the result away, so `Focus.focus("a", "b")` only ever returns `a`. It should be `focus = focus:union(...)`.