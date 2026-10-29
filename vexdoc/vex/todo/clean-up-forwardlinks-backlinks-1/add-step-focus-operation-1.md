---
vexid: add-step-focus-operation-1
vextype: atom
description: Add a step focus operation
created: "2026-10-29 23:56:11"
dependencies: 
  - "[[make-backlinks-forwardlinks-1]]"
modified: "2026-10-29 23:56:12"
status: todo
---
Add `--step <field>` to src/core/focus.lua (Focus:step, registered in the operations list and the CLI parser): replace every task in the focus with the tasks its `field` points to, one hop only. `vex focus x --step children` gives x's immediate children; `--step backlinks` and `--step forwardlinks` work the same once those are transients. It is the single-hop counterpart of `--tree`/`--reversetree`. Document it in [[01 CLI reference]] and [[05 Getting into focus]]. Verify: unit test in test/unit/core/focus_spec.lua, e2e in test/e2e/linking_spec.lua, and a smoke_spec.lua row.