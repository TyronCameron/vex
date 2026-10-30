---
vexid: read-iso-8601-datetimes-zones-1
vextype: atom
description: Read ISO 8601 datetimes with zones
created: "2026-10-30 07:09:09"
modified: "2026-10-30 07:09:14"
status: done
---
The `datetime` format iso (`src/lib/schema.lua`) only read `YYYY-MM-DD[T ]HH:MM:SS`. It now also reads times without seconds, fractional seconds and a `Z` or `±HH[:]MM` zone, converting to the same instant, as TaskNotes writes them. Documented in [[02 Frontmatter schema]]; verified in `test/unit/lib/schema_spec.lua`.