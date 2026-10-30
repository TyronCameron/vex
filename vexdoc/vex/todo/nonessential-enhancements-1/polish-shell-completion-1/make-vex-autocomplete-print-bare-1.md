---
vexid: make-vex-autocomplete-print-bare-1
vextype: atom
description: Make vex autocomplete print a bare script
created: "2026-10-19 09:21:54"
modified: "2026-10-30 03:17:28"
status: todo
---

[[01 Installing vex]] says to print the completion script and add it to your shell's startup file. `vex autocomplete bash` wraps the script in a "Please copy the snippet below" line and a `lua` code fence, so `vex autocomplete bash >> ~/.bashrc` writes a broken rc file. Print only the script, and put the instructions in the verb's `doc`.
