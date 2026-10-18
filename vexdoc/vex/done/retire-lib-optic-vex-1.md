---
vexid: retire-lib-optic-vex-1
vextype: task
description: Retire lib.optic from vex
created: "2026-10-16 23:10:52"
modified: "2026-10-17 22:15:23"
status: done
---
src/lib/optic.lua (435 lines, plus test/unit/lib/optic_spec.lua) is a general-purpose optics library (field/iso/filter/fold/traverse/chain/fanout/cartesian, with get and set) that vex barely uses. Its only callers are Focus:tree and Focus:reversetree in src/core/focus.lua, which use optic.chain(optic.ipairs(), optic.traverse(children)):get(tasks) as a cycle-safe depth-first walk over linked tasks. Nothing calls Optic:set, iso, fanout, cartesian or the folds. Either replace those two calls with a small traversal helper (in focus.lua or src/lib/func.lua) and delete lib.optic and its spec, or move lib.optic out into its own package and depend on it. Keep the tree/reversetree behaviour (including cycle safety) covered by focus_spec before removing it. Once done: drop the optic.traverse mention from CLAUDE.md's 'Where code goes', and close stop-optic-set-swallowing-1 as no longer relevant.