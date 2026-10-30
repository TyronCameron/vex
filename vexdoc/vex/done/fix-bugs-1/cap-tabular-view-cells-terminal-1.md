---
vexid: cap-tabular-view-cells-terminal-1
vextype: atom
description: Cap tabular view cells at a terminal-friendly width
created: "2026-10-24 12:50:16"
modified: "2026-10-30 01:33:49"
status: done
---
`pretty.tabular` (`src/lib/pretty.lua`) sized each column to its widest value, so a long description pushed `vex view tabular` past the terminal width; only lists were capped. Widths and padding also counted bytes, so UTF-8 values broke the right border, and a newline in a value split a row. [[04 Views]] promises a table formatted for reading.

Cap every cell and header at 40 visible characters (an optional `maxwidth` argument), ending in `...`, cut lists between values, count width in characters ignoring ANSI codes, and turn newlines and tabs into spaces. Verify with the `pretty.tabular` specs in `test/unit/lib/pretty_spec.lua` and `just test`.