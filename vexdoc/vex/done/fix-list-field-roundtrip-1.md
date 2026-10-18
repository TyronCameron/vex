---
vexid: fix-list-field-roundtrip-1
vextype: task
description: List-typed fields never survive a disk round-trip
created: "2026-07-06 12:00:00"
modified: "2026-07-11 22:00:00"
status: done
---

Fixed. `src/default/obsidian.lua`'s `read` now tracks the last real key seen while scanning frontmatter lines, and accumulates indented `- item` continuation lines into a table under that key, matching the multi-line array format `to_yaml_value` (the writer, same file) already produced. A written array like:

```yaml
children:
  - "[[some-task]]"
```

now reads back as a real Lua table (`children = {"[[some-task]]"}`), not `children = ""`.

Empty lists needed a separate tweak: `to_yaml_value` couldn't previously distinguish an empty array from an empty map (both produced a bare, stray blank line), so a schema-defaulted `children = {}` round-tripped to `""` too. `to_yaml_value` now serializes any empty table as `[]`, and `read` recognises a literal `[]` value as an explicit empty table. `vex add X --vextype abstract` followed by `vex resolve all` — twice in a row — now succeeds both times. Covered by new unit tests in `test/unit/default/obsidian_spec.lua` and an e2e regression in `test/e2e/lifecycle_spec.lua`.

Note: this only fixes the disk round-trip. Setting a list field directly via a CLI flag (`--children`/`--dependencies`/`--options`) is still not implemented — that's tracked separately in `implement-cli-list-fields-1`.
