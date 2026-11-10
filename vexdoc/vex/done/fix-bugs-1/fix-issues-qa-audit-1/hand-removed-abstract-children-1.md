---
vexid: hand-removed-abstract-children-1
vextype: atom
description: "Hand a removed abstract's children to its parent"
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
Removing an abstract left its children without a parent. `TaskManager:remove` now moves them into the removed abstract's parent's `children`.