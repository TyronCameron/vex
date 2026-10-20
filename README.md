# vex

[![Docs](https://img.shields.io/badge/docs-tyroncameron.github.io%2Fvex-22d3ee)](https://tyroncameron.github.io/vex/)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![LuaJIT](https://img.shields.io/badge/runs%20on-LuaJIT-000080)](https://luajit.org/)
![Status](https://img.shields.io/badge/status-v0.0.0%2C%20in%20development-orange)

**The embeddable, local-first, markdown-based task system.**

Every task is a plain-text markdown file with YAML frontmatter, and every project keeps its own `.vex` folder, much like a `.git` folder. There is no server, no daemon and no account. Because a task is a text file, anything that reads and writes text can work with it: your editor, a shell script, git, or an AI coding agent.

📖 **Documentation: [tyroncameron.github.io/vex](https://tyroncameron.github.io/vex/)**

## A taste

```console
$ vex init
$ vex add Ship the billing rewrite --vextype abstract
ship-billing-rewrite-1
$ vex add Migrate existing invoices
migrate-existing-invoices-1
$ vex add Fix the flaky webhook retry
fix-flaky-webhook-retry-1
$ vex set ship-billing-rewrite-1 --children migrate-existing-invoices-1,fix-flaky-webhook-retry-1
$ vex set fix-flaky-webhook-retry-1 --status doing
$ vex view all kanban
┌───────────────────────────┬─────────────────────────────┐
│ doing                     │ todo                        │
├───────────────────────────┼─────────────────────────────┤
│ fix-flaky-webhook-retry-1 │ migrate-existing-invoices-1 │
│                           │ ship-billing-rewrite-1      │
└───────────────────────────┴─────────────────────────────┘
```

Each of those tasks is now a markdown file you can open, edit, link in Obsidian and commit.

## Features

- **Tasks as files.** Markdown with YAML frontmatter, validated against a schema and indexed for speed.
- **Focuses.** Saved, composable queries: filter, fuzzy-match, compare dates written as phrases (`--interpret --between due:now:"next tuesday"`), walk children and dependencies, group, order and number.
- **Views.** Tables, CSV, JSON, kanban boards, project statistics and a dependency view of any task.
- **Opinionated task types.** Abstracts group work, explorations mark open questions, decisions choose a path and atoms get done.
- **Extensible from your project.** Add task types, computed fields, recipes, focuses, views and event hooks with a Lua file in `.vex`, no build step required.
- **Runs on a potato.** A single LuaJIT program.

## Install

You need [LuaJIT](https://luajit.org/).

```console
$ git clone https://github.com/TyronCameron/vex.git
$ ln -s "$(pwd)/vex/src/vex" /usr/local/bin/vex
$ vex help
```

Then follow [Creating your first task](https://tyroncameron.github.io/vex/docs/01-getting-started/02-creating-your-first-task-using-vex/).

## Documentation

- [Getting started](https://tyroncameron.github.io/vex/docs/01-getting-started/): install vex, create tasks, use recipes.
- [CLI reference](https://tyroncameron.github.io/vex/docs/02-features/01-cli-reference/): every command, focus and flag.
- [Configuration](https://tyroncameron.github.io/vex/docs/03-configuration/): `config.lua` and extending vex from `.vex`.
- [Technical documentation](https://tyroncameron.github.io/vex/docs/04-technical-documentation/): plugins, the index and events.

The docs are written in [`vexdoc/`](vexdoc), an Obsidian vault that also holds this project's own backlog as vex tasks in [`vexdoc/vex/`](vexdoc/vex).

## Contributing

```console
$ just test
```

runs the unit tests, end-to-end tests and lint, and needs `luajit`, `busted`, `luacheck` and `just`. See [CLAUDE.md](CLAUDE.md) for how the code is organised.

## License

[MIT](LICENSE) © Tyron Cameron
