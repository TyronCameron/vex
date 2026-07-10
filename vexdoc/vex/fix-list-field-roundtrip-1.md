---
vexid: fix-list-field-roundtrip-1
vextype: task
description: List-typed fields never survive a disk round-trip
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

Bigger than `implement-cli-list-fields-1` (which only covers the CLI-flag side): confirmed by testing that `children`, `dependencies`, and `options` don't survive being written to disk and read back **at all**, through any means, not just via a CLI flag. `src/default/obsidian.lua`'s `read` function parses frontmatter one line at a time with `line:match("^([%w_]+):%s*(.*)$")` — it has no support for multi-line YAML lists at all. A written array like:

```yaml
children:
  - "[[some-task]]"
```

reads back as `children = ""` (the continuation `- item` lines don't match the key:value pattern and are silently dropped). This isn't just "can't set from CLI" — it means an `abstract` task with an (empty, schema-defaulted) `children` list **fails validation the very next time it's resolved from disk**, since the round-tripped value is a string, not a table, and `schema.vec` requires a table. Reproduced with: `vex add X --vextype abstract` (succeeds), then `vex resolve all` again (fails on the same task, every time, from then on).

Practical impact: `abstract` and `decision` tasks are currently unusable across more than one resolve pass — including the very common case of `vex resolve all` as a git pre-commit hook (recommended in the wiki's CLI reference), which would fail on any project that has ever created an `abstract` task. `to_yaml_value` (the writer, same file) already handles arrays correctly; only the reader is missing multi-line list support. Fixing the reader to parse its own multi-line array format back into a table would resolve this, `implement-cli-list-fields-1`, and the "not schema-validated" caveat that currently applies to `children`/`dependencies`/`options` in practice.
