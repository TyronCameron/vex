---
vexid: show-command-behind-saved-focus-1
vextype: atom
description: Show the command behind the saved focus
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
`vex focus` without arguments dumped a Lua table, and `pretty.any` left a trailing tab on every line. It now prints the `vex focus` command that rebuilds the focus, counts tasks rather than vexes, and lines have no trailing tab.