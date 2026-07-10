---
vexid: implement-owner-assignment-1
vextype: task
description: Make owner a real, validated field
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`owner` shows up in the wiki's Frontmatter schema page but has no entry in `core/taskdefinitions.lua` — today it's just an arbitrary unvalidated string, same as any other extra frontmatter key. It's the whole basis for the git-based "assigning work to a teammate" workflow documented on the Home page, so it's worth making real: a `vexlink`-style validated field (or at minimum a documented convention), rather than something a typo silently breaks.

Note: vex has no concept of users/accounts at all, and probably shouldn't grow one — the git-based workflow works precisely because vex stays out of syncing/notifying. This task is about validating the field, not about building multi-user infrastructure.

However, vex *should* have the concept of a categorical variable as defined in tasktypes, see [[implement-categorical-variables-1]]