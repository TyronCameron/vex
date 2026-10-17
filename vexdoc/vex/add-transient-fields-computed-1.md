---
vexid: add-transient-fields-computed-1
vextype: task
description: Add transient fields computed on read
created: "2026-10-17 02:07:33"
modified: "2026-10-17 05:36:46"
status: done
---
Transients are task fields that are never stored but computed every time they are read, from the task itself and the vexdex. Unlike schema `derive` fields, nothing about them reaches the task file or the index.

A transient is registered on a task type, kept apart from the task type's schema: `task:transient 'wordcount' { vextype = 'task', definition = function(t) ... end }`. Subtypes inherit their ancestors' transients and can override them. Projects add their own in `.vex/tasks/*.lua`.

They work through `Task.__index`: reading a field a task doesn't hold falls back to the transient of that name for the task's type, so stored fields always win, only the transient asked for is computed, transients can use each other, and they work from the moment a task exists in memory (before it is resolved, indexed or written). Focuses read `task[field]`, so `filter`, `fuzzy`, `select`, `tree` and views get transients with no extra code. `vex get <vexid> --<transient>` reads them too.

Built-in transients on `task`: `wordcount` (words in the description), `phase` (initial, interim or final in the status state machine; the `initial`/`interim`/`final` focuses filter on it), `ancestors` (parent vexids, nearest first), `path` (absolute path of the task file) and `age` (whole days since creation).

Transients that only read the task itself work in memory, before it is indexed. One that queries the vexdex, like `ancestors`, needs the task to be indexed. A task can't have a parent before it is linked, and linking is a `set`, so that is always the case.