---
vexid: make-options-children-1
vextype: atom
description: "Make options, children and dependencies mutually exclusive"
created: "2026-10-29 08:09:36"
modified: "2026-10-29 08:09:36"
status: todo
---
A task holds at most one of `children`, `options` and `dependencies`: all three are sets of vexids, and `options` should count as children for dependency purposes. Decisions never get dependencies.

Missing today: `childless` and `haschildren` in `src/core/taskdefinitions.lua` (rule `dependency-with-children`) only look at `children`. So a `decision` (its `options` are links) can still hold `dependencies` and be depended on, and one task can hold children, options and dependencies together.

Wanted: a task with `options` is treated as having children by the dependency rule, as dependent and as target; a `decision` never holds `dependencies`; more than one non-empty set among `children`, `options`, `dependencies` is rejected with a named error registered in `src/core/errors.lua`. Open point: whether `children` plus `options` on one abstract is rejected too (the stated rule says yes).

Docs that state the rule: [[Frontmatter schema]], [[Task types (and vexations)]] and the schema paragraph of CLAUDE.md.

Verify: unit specs in `test/unit/core/taskdefinitions_spec.lua` (decision with dependencies, depending on a decision, a task with two sets), an e2e row in `test/e2e/errors_spec.lua`, and `just test` green including `dogfood_spec` (check no backlog task already mixes the sets).