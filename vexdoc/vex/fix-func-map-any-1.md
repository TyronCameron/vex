---
vexid: fix-func-map-any-1
vextype: task
description: Fix func map and any helpers
created: "2026-10-13 22:14:55"
modified: "2026-10-14 22:13:55"
status: done
---
Fixed. func.map writes res[i]. count, any and all name their predicate f, so the func module is no longer shadowed. any and all are seeded with false and true, so empty tables work. count counts the values of the sparse filter result.