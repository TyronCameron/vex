---
vexid: design-vexql-query-language-1
vextype: atom
description: Design a vexQL query language for focuses
created: "2026-10-19 20:55:59"
modified: "2026-10-19 20:55:59"
status: todo
---

The design journal ([[Vex]], "Plugins") lists a query plugin, "vexQL". Focuses are built from flags today (`--filter status:todo --orderby due`). Explore whether a small textual query language (e.g. `status = todo and due < "next week" order by due`) would earn its place, compiling to the same `Focus` operations so focuses still serialise. Write the outcome into this body before building anything, and split the build into atoms if it goes ahead.
