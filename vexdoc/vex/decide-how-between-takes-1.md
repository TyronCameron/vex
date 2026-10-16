---
vexid: decide-how-between-takes-1
vextype: task
description: Decide how between takes datetime bounds
created: "2026-10-16 02:02:23"
modified: "2026-10-16 02:02:23"
status: todo
---
Design decision, raised while fixing [[fix-between-focus-crashing-1]]. `--between field:begin:end` now converts each bound through the field's schema, so `cost:1:9` works. Datetime fields (`due`, `created`, `modified`) cannot be filtered yet, for two reasons. `Focus.parse` splits flag values on `:`, so a full `YYYY-MM-DD HH:MM:SS` bound is torn apart. And the `datetime` schema's format iso only accepts a full date and time, so a date-only bound like `2026-01-01` does not parse. Today such a bound gives a usage error ("Cannot compare `due` with `2026-01-01`").

Options: (a) let `datetime` also read a date-only value as midnight; (b) give `between` a separator that cannot appear in a datetime (e.g. `due:2026-01-01..2026-06-01`); (c) both. The pending row in `test/e2e/smoke_spec.lua` (`--between due:...`) should pass once this is decided.