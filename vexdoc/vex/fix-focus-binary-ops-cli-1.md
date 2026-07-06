---
vexid: fix-focus-binary-ops-cli-1
vextype: task
description: Fix union/intersect/xor/notin/onlyin crashing from the CLI
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

Confirmed by testing: `vex focus all --union all`, `--intersect all`, and (by the same code path) presumably `--xor`/`--notin`/`--onlyin` all crash with "Internal error ... attempt to call method 'get' (a nil value)". `Focus:union`/`Focus:intersect`/etc. (`core/focus.lua`) expect a Focus *object* as their argument (they call `focus:get(tasks)` on it), but `Focus.parse` passes whatever raw string came from the CLI flag value (e.g. `"all"`) straight through — never resolving it to an actual named focus first. `--complement` works fine since it takes no argument at all. Needs `Focus.parse` (or the binary-op methods themselves) to resolve a string argument through `namedfocus.focus(...)` before calling it.
