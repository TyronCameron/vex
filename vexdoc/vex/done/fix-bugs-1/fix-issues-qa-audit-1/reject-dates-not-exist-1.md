---
vexid: reject-dates-not-exist-1
vextype: atom
description: Reject dates that do not exist
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
`--due 2026-02-30` became 2 March and `2026-13-45` became February. `naturaltime.exists` now checks the calendar day, `settle` rejects a date that doesn't exist, `clock` rejects hours over 23 and minutes over 59, and the `date`/`datetime` format isos only read real dates. Unknown-word errors no longer name the number before the unknown word.