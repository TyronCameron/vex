---
vexid: add-config-switch-turn-event-1
vextype: atom
description: Add a config switch to turn event hooks off
created: "2026-10-19 20:55:58"
modified: "2026-10-19 20:55:58"
status: todo
---

The design journal ([[Vex]], "Config folder") lists "allow hooks: true/false". `core.extensions` always runs every file in `.vex/events`. Add a `hooks = false` config setting that skips loading `.vex/events`, e.g. when running untrusted project hooks or debugging a hook that blocks every command. Document it in [[01 Configuring vex (config.lua)]] and [[06 Configuring event hooks]].
