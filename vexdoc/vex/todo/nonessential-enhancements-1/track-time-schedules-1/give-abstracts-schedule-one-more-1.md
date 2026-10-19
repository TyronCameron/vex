---
vexid: give-abstracts-schedule-one-more-1
vextype: atom
description: Give abstracts a schedule of one or more time intervals
created: "2026-10-19 20:55:58"
modified: "2026-10-19 20:55:58"
status: todo
---

The design journal ([[Vex]], "Schedules") says abstracts can have schedules: an interval of time, or a union of intervals. Atoms keep single dates such as `due`. Add an optional `schedule` field on `abstract`: a list of `{start, finish}` datetimes, each read through the natural-time interpreter like other dates. Validate that each interval's start comes before its finish. Make `--between` (or a new focus operation) able to ask whether a schedule overlaps a range. Decide how intervals look in YAML frontmatter, which `default.obsidian` writes flat today.
