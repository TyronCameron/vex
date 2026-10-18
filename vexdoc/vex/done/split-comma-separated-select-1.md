---
vexid: split-comma-separated-select-1
vextype: task
description: Split comma-separated select fields into separate fields
created: "2026-10-17 02:11:48"
modified: "2026-10-17 21:13:10"
status: done
---
`vex focus all --select phase,wordcount` selects a single field literally named `phase,wordcount`, so only `vexid` survives. `Focus.parse` (`src/core/focus.lua`) splits flag values on `:` only, although `Focus:select` is documented as `select comma,sep,values` and the `get` verb's example uses `--select due,id,description`. `--select phase wordcount` doesn't help either: the flag keeps only its first value, so there is currently no way to select more than one field from the CLI.