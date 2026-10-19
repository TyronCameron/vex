---
vexid: ensure-abstract-works-fully-1
vextype: atom
description: Ensure abstract works fully
created: "2026-10-19 07:28:34"
modified: "2026-10-19 09:22:04"
status: todo
---

Check every promise [[03 Task types (and vexations)]] and [[02 Frontmatter schema]] make about `abstract`, and add e2e coverage for any that lacks it: `children` defaults to an empty list, the body must be empty, a task can be the child of only one abstract and not of itself, `lineage` and `--reversetree children` walk up from a child, and moving a child moves its file under `paths.groupby`.
