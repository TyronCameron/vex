---
vexid: stop-schema-literals-matching-1
vextype: task
description: Stop schema literals matching templates
created: "2026-10-14 22:19:34"
modified: "2026-10-14 22:19:34"
status: todo
---
`Schema.instantiate` (`src/lib/schema.lua`) checks `templates[name]` before treating a value as a constant. A literal string that happens to name a template becomes that template: `schema.any {"str"}` accepts any string, and a configured user named `date`/`num`/`empty` would turn `owner` into a type check. Literals inside combinators like `any` should always be constants. One option: only instantiate templates for actual schema objects, and wrap everything else in `constant`.