---
vexid: read-yaml-flow-lists-lists-maps-1
vextype: atom
description: Read YAML flow lists and lists of maps in task files
created: "2026-10-30 07:09:09"
modified: "2026-10-30 07:09:14"
status: done
---
Task files shared with Obsidian plugins such as TaskNotes hold flow lists (`contexts: [a, b]`) and lists of maps (`blockedBy`, `timeEntries`, `reminders`). The `obsidian` taskformat (`src/default/obsidian.lua`) read flow lists as strings and flattened lists of maps into strings, so the next write lost data. It now reads indented YAML blocks (maps, lists, lists of maps, a list at its key's indent, empty keys as nil) and flow lists, and writes map keys in sorted order. Verified in `test/unit/default/obsidian_spec.lua` and `test/e2e/storage_spec.lua`.