---
vexid: implement-categorical-variables-1
vextype: task
description: Implement categorical variables
created: "2026-07-10 22:13:08"
modified: "2026-10-14 22:14:35"
status: done
---
Closed: no new machinery needed. A categorical variable is schema.any over constants, e.g. schema.any {'low', 'medium', 'high'}; covered by a test in schema_spec.lua. The owner field is the first one that uses it.