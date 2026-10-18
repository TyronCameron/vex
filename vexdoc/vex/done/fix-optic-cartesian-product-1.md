---
vexid: fix-optic-cartesian-product-1
vextype: task
description: Fix optic cartesian product
created: "2026-10-14 22:19:34"
modified: "2026-10-16 02:05:05"
status: done
---
`Optic.cartesian` (`src/lib/optic.lua`) cannot work. `increment_multi_index` loops `for i = #indexes, 1` with no `-1` step, so it runs at most once. `cartesian_product_gen` assigns to undefined globals `index` / passes `index` instead of `indexes`. Its cardinality fold seeds with the number `1`, not a `Cardinality`. Nothing uses it yet. Fix it with tests, or remove it.