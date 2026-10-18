---
vexid: implement-event-hooks-1
vextype: task
description: Implement event hooks
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

`.vex/events` is created by `vex init` but nothing reads it. `lib/event.lua` is still `return {}`. Wire up `pre-[verb]`/`post-[verb]` dispatch so files dropped in `.vex/events` can hook into resolution — found while writing the wiki's Configuring event hooks page, which currently has to document this as intent rather than behaviour.
