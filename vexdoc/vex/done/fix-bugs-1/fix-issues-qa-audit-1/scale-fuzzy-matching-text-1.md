---
vexid: scale-fuzzy-matching-text-1
vextype: atom
description: Scale fuzzy matching with the text
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
`--fuzzy vexid:book` matched nearly every task, with a flat 3 edits on a 4-character window. `Focus:fuzzy` now allows one edit per four characters unless given `:n`, and ignores case.