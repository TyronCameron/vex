---
vexid: tag-tasks-config-rules-manual-1
vextype: atom
description: Tag tasks automatically from config rules with manual overrides
created: "2026-11-04 22:20:35"
modified: "2026-11-04 22:20:41"
status: done
---
Every task should carry tags (a # and a word without spaces), some set by rules in the config and some by hand, without either undoing the other. A diff of old and new rule output breaks when the rules change, so tags are level-triggered: `manualtags` holds overrides (`#x` always, `-#x` never, last entry wins), `config.autotags` maps tag names to predicates of the resolved task, and `TaskManager:resolvesingle` stores the `effectivetags` transient as `tags`. `--contains field:value` queries lists and sets. See [[02 Frontmatter schema]] and [[01 Configuring vex (config.lua)]]. Verify with test/e2e/tags_spec.lua.