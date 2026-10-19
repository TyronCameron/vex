---
vexid: add-llm-pushback-mode-critiques-1
vextype: atom
description: Add an LLM pushback mode that critiques new tasks
created: "2026-10-19 20:55:59"
modified: "2026-10-19 20:55:59"
status: todo
---

The design journal ([[Vex]], "Plugins") lists "Pushback mode from LLM": an assistant that challenges tasks as they are written. Examples: an atom too big for one session, an abstract that hides a decision, a vague description. Explore it as a plugin hooked on `post-task-add` and `post-task-set` ([[06 Configuring event hooks]]), calling a configured model and printing its critique without blocking the command. Keep it opt-in and off by default, since vex has no network dependency today.
