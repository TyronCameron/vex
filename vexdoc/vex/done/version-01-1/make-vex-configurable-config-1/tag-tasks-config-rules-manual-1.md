---
vexid: tag-tasks-config-rules-manual-1
vextype: atom
description: Tag tasks automatically from config rules with manual overrides
created: "2026-11-04 22:20:35"
dependencies: 
  - "[[merge-task-type-schemas-field-1]]"
modified: "2026-11-05 22:27:00"
status: done
---
Every task should carry tags (a # and a word without spaces), some set by rules in the config and some by hand, without either undoing the other. A diff of old and new rule output breaks when the rules change, so tags are level-triggered: `manualtags` holds overrides (`#x` always, `-#x` never, and never wins), `config.autotags` maps tag names to predicates of the resolved task, and `basetask`'s `tags` is a `schema.autotagged` whose postvalidate derives it. That needs every field resolved first, so it depends on [[merge-task-type-schemas-field-1]]. `--contains field:value` checks a list or a set for a value. See [[02 Frontmatter schema]] and [[01 Configuring vex (config.lua)]]. Verify with test/e2e/tags_spec.lua.