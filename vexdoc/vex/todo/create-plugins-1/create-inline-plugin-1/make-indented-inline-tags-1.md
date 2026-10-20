---
vexid: make-indented-inline-tags-1
vextype: atom
description: Make indented inline tags children of the tag above
created: "2026-10-19 09:21:54"
dependencies: 
  - "[[implement-inline-plugin-1]]"
modified: "2026-10-19 09:22:08"
status: todo
---

[[01 CLI reference#Inline tags]]: an indented tag becomes a child of the tag above it. When `vex inline` meets an indented tag under another tag, add it to the parent's `children` (the parent must then be an `abstract`). Cover nested and sibling tags in an e2e test.
