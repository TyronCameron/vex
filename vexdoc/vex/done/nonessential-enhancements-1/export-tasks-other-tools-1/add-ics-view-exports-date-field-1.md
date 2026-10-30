---
vexid: add-ics-view-exports-date-field-1
vextype: atom
description: Add an ics view that exports a date field as calendar events
created: "2026-10-19 20:55:57"
modified: "2026-10-30 22:40:04"
status: done
---

The design journal ([[Vex]], "Plugins") lists "Export to .ics". Add an `ics` view that writes the focus as an iCalendar file, so tasks can be added to any calendar app:

```txt
vex view all ics > tasks.ics
vex view all ics --field created
```

- `--field` picks the date field, the same way `kanban` takes `--field`. It defaults to `due`. Any `date` or `datetime` field works, including fields from custom task types. A field that isn't a date fails with a named error.
- Each task with a value in that field becomes one `VEVENT`. `UID` is `<vexid>@vex` so re-importing updates events rather than duplicating them, `SUMMARY` is the description, `DTSTART` is the field's value, and `DESCRIPTION` holds the vexid, type and status. A value at exactly midnight could be an all-day event (`VALUE=DATE`). Tasks without the field are skipped.
- Escape `,`, `;` and newlines in text, and fold lines at 75 octets, as RFC 5545 requires.

Verify with a unit test in `test/unit/core/view_spec.lua`, a row in `test/e2e/smoke_spec.lua` (it fails for an unlisted view), and a section in [[04 Views]].
