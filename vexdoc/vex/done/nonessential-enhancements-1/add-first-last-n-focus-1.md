---
vexid: add-first-last-n-focus-1
vextype: atom
description: Add first and last n focus operations
created: "2026-10-29 22:31:16"
modified: "2026-10-30 03:17:28"
status: done
---

Add `--first n` and `--last n` focus operations to keep only the first or last `n` tasks:

```console
$ vex focus all --orderby created:desc --first 10
$ vex focus all --orderby created:desc --last 10
```

- **Where.** `Focus:first(n)` and `Focus:last(n)` in `src/core/focus.lua`, built on `Focus:chain` with `func.first` / `func.last`, and added to the `operations` list so `Focus:apply` accepts them.
- **Order.** The result follows the operations before it, so `--first` is only meaningful after `--orderby`. Do not invent an implicit sort. `--last` keeps the original order rather than reversing.
- **Groups.** `chain` runs per group, so after `--groupby owner`, `--first 3` keeps 3 per group, as `rn` numbers per group.
- **Argument.** `n` arrives as a string from `Focus:apply`. Convert it; a non-number, zero or negative value is a `usage` error. An `n` larger than the list returns everything; check `func.last` when `n > #tab`.
- **Persistence.** Operations replay from the saved focus, so the number must round-trip through `focus.bin`.

Verify: unit tests in `test/unit/core/focus_spec.lua` (plain, grouped, `n` too large, bad `n`); an e2e test of both examples; both flags in `smoke_spec.lua`; documented in [[01 CLI reference]] and [[05 Configuring focuses]].
