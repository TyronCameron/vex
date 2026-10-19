---
vexid: add-recur-field-reads-phrases-1
vextype: atom
description: Add a recur field that reads phrases like every week
created: "2026-10-19 21:29:42"
modified: "2026-10-19 21:29:42"
status: todo
---

Recurrence should be easy to write:

```txt
vex add Water the plants --recur "every week"
vex add Pay rent --due "the 1st" --recur "every month"
vex add Stand-up --recur "every weekday 9am"
```

Add an optional `recur` field to the base `task` schema. It stores a normalised rule (an interval or a weekday/day-of-month pattern) and formats back to readable text, as an iso like the other formatted fields. It reads phrases through `src/lib/naturaltime.lua`, which needs an `every` form: `every day`, `every 2 weeks`, `every monday`, `every weekday`, `every month on the 15th`. Unreadable phrases raise `uninterpretable`. Expose the next occurrence after a given time, e.g. `naturaltime.next(rule, from)`. Unit-test the parser in `test/unit/lib/naturaltime_spec.lua`, and add the field to [[02 Frontmatter schema]].
