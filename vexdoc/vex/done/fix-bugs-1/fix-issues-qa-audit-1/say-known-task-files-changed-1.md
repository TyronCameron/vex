---
vexid: say-known-task-files-changed-1
vextype: atom
description: Say known task files changed in the stale warning
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
The read verbs' warning counted only indexed files, so after deletions and new files it undercounted. It now says `Known task files changed since vex last saw them`, without a count.