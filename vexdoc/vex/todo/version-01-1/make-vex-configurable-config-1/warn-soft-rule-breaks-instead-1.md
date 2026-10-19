---
vexid: warn-soft-rule-breaks-instead-1
vextype: atom
description: "Warn about soft rule breaks instead of failing, switchable in config"
created: "2026-10-19 20:55:58"
modified: "2026-10-19 20:55:58"
status: todo
---

The design journal ([[Vex]], "validation" and "Config folder") says vex validates tasks and warns users by default, with warnings switchable in config. Today every rule is a hard failure. An abstract with a body fails, where the journal wanted a warning that says to move the text into an exploration. Decide which rules are soft. Add a warning channel (printed to stderr, never failing the command) that the schema can raise, and a `warnings = false` config setting.
