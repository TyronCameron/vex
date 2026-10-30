---
vexid: reject-abstract-listing-itself-1
vextype: atom
description: Reject an abstract listing itself as a child
created: "2026-10-18 04:21:22"
modified: "2026-10-30 01:33:49"
status: done
---
An abstract can list its own vexid in `children` and still resolve: the `singleparent` constraint in `src/core/taskdefinitions.lua` only compares against other parents, and nothing else rejects a self-link. Found when a recipe example appended the parent to the same `stages` table it passed as `children`. Resolution should reject a task that lists itself in `children` (and likely in `dependencies`, which `acyclic` may already catch), with a named error.