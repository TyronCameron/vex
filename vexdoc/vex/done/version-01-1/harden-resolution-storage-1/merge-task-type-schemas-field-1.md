---
vexid: merge-task-type-schemas-field-1
vextype: atom
description: Merge task type schemas field by field
created: "2026-11-05 22:18:04"
modified: "2026-11-05 22:18:11"
status: done
---
Resolution ran each ancestor type's schema as its own prevalidate, validate, postvalidate pass, root first, so a derive on `basetask` ran before a subtype defaulted its fields (a new atom had no `status` yet, and `phase` crashed on it). `func.merge` and `Schema:merge` (same schema type only; the specifications merge, the second's keys winning) now let `TaskManager:registertask` merge each type's schema over its parent's once, and resolve, format, unformat, `forwardlinks` and `schemaof` use that one schema. A type's field replaces its ancestor's definition instead of stacking on it. See [[Resolution pipeline]] and [[03 Configuring task types]]. Verify with the merge tests in test/unit/lib/schema_spec.lua and test/unit/core/task_spec.lua.