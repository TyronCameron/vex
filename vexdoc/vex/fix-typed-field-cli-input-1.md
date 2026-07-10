---
vexid: fix-typed-field-cli-input-1
vextype: task
description: Fix numeric and datetime fields failing validation from the CLI
created: "2026-07-06 12:00:00"
modified: "2026-07-06 12:00:00"
status: todo
---

Confirmed by actually running the CLI while writing the wiki: `due` and `cost`/`benefit` currently **always** fail resolution, whether set via `--due`/`--cost`/`--benefit` or by hand-editing the YAML frontmatter directly and running `vex resolve`. Reproduced with `vex add Buy new mug --cost 15 --benefit 40` (fails: "The instance: `40` is not a number") and with `due: "2026-07-10 09:00:00"` written directly into a task file (fails: `datetime` validation on the raw, still-a-string value). `schema.num` has no string-to-number coercion at all, and `schema.formatted{datetime}`'s prevalidate isn't actually converting the string before the inner `datetime` schema validates it — worth checking `formatted`'s `iterate` (`coroutine.yield(1, nil)`) since that looks like it may be short-circuiting `self:validate(instance)` inside `formatted:prevalidate` before the real string→epoch conversion runs.

By contrast, `status` (a string, matched directly against the statemachine) and plain string/unvalidated fields (`owner`, `description`, etc.) work fine via the CLI today. This means, right now, only string-typed fields can reliably be set through `add`/`set` — `due`, `cost`, and `benefit` can't be set at all (not just "not via a flag," as with the list-typed fields tracked in `implement-cli-list-fields-1` — these fail even from a hand-edited file). Found while trying to write a working `--due` example for the wiki's Getting Started and CLI reference pages, which had to be rewritten to avoid teaching a currently-broken flag as if it worked.
