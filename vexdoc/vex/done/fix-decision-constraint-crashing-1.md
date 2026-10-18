---
vexid: fix-decision-constraint-crashing-1
vextype: task
description: Fix decision constraint crashing
created: "2026-10-15 13:02:26"
modified: "2026-10-16 02:05:04"
status: done
---
Found by the new task round-trip unit test. The `decision` field's constraint in `src/core/taskdefinitions.lua` is written as `function(self, instance, context)`, but `schema.constraint` calls its function with `(instance, context)` (compare `acyclic(dependency, context)`). So `context` is nil, and setting `decision` on any decision task crashes resolution ("attempt to index local 'context'").