---
vexid: write-plain-config-yaml-lists-1
vextype: atom
description: Write a plain config and YAML lists
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
`vex init` wrote `config.lua` with `[1] =` list keys and no trailing newline, and YAML lists followed `key: ` with a trailing space. `format.lua` now writes Lua literals, and `obsidian.render` writes `key:` before a list or map.