Welcome to the vex wiki. vex is **the embeddable, local-first, minimal-and-meta task system** — every task is a plain text file, every project keeps its own `.vex` folder (much like a `.git` folder), and there is no server, no account, and no lock-in.

> [!NOTE] Project status
> vex is early (`v0.1.0`), built by a single developer, and designed around a **single operator working locally**. There is no built-in multi-user server, notification system, or sync — see [[#Powerful, real-world]] below for how teams use it anyway. Several pages under **03 Configuration** (linked below) intentionally describe features that are **not yet implemented** — they document real design intent, not real behaviour, until that callout is gone. There's also a more fundamental confirmed bug worth knowing up front: task-linking fields (`children`, `dependencies`, `options`) don't survive being saved and reloaded, so `abstract`/`decision` structure and dependency graphs aren't usable yet — see the warning in example 1 below, and [[02 Frontmatter schema]].

Because a task is just a text file, anything that can read and write text — your editor, a shell script, or an AI coding agent — can create, update, and reason about your tasks with no special API. That's not a bolted-on integration; it's the whole design.

## Find your way around

- **[[01 Installing vex]]** — get the `vex` binary running and shell completion set up.
- **[[02 Creating your first task using vex]]** — `init`, `add`, `show`, `resolve` in five minutes.
- **[[03 Using a recipe to create a sequence of tasks]]** — stamp out a whole structure of tasks in one command.
- **Features**
  - **[[01 CLI reference]]** — every command, every flag.
  - **[[03 Vexations (task types)]]** — `exploration`, `abstract`, `decision`, `atom`, and how they chain together.
  - **[[02 Frontmatter schema]]** — every field a task file can carry.
  - **[[04 Views]]** — tabular, kanban, overview, dependency diagrams, and more.
- **Configuration**
  - **[[01 Configuring vex (config.lua)]]** — the one config file that's actually loaded today.
  - **[[06 Configuring event hooks]]**, **[[05 Configuring focuses]]**, **[[04 Configuring recipes]]**, **[[03 Configuring task types]]**, **[[02 Configuring views]]** — the extension points that are scaffolded but not wired up yet.
- **Technical documentation**
  - **[[Plugin architecture]]** — how every piece of vex's behaviour, including its default file format, is a swappable plugin.
  - **[[The index]]**, **[[Configuration]]**, **[[Events and hooks]]** — the internals of the `.vex/vexdex` folder.
- **[[Vex]]** — the original design journal. Read it for the "why" behind the above; read everything else for the "how."

## Powerful, real-world

vex is deliberately small, but small pieces compose into things that would otherwise need a much heavier tool. Three examples, all things you can actually run today:

### 1. A solo developer triaging a pile of small tasks

You're building a feature alone and the backlog is a mess of half-formed ideas at different levels of detail. Capture is fast regardless of shape:

```txt
vex add Ship the billing rewrite --vextype abstract
vex add Migrate existing invoices --vextype atom
vex add Fix the flaky webhook retry --owner alice --status doing
```

Then triage without opening a single file:

```txt
vex focus all --filter status:doing
vex view tabular
```

```txt
vex view all kanban --field status
```

...to see everything grouped into columns by status, or `vex view all overview` for a scope/quality/structure/movement summary across the whole backlog. None of this needed a project management tool with logins and a database — it's a folder of markdown files you can grep, diff, and commit.

> [!WARNING] The dependency-graph story isn't real yet
> vex is *designed* so `abstract` tasks group children, `atom`s declare `dependencies`, and the `singular` view draws the resulting tree/DAG (see [[03 Vexations (task types)]] and [[04 Views]]) — that's the part of this tool that would really set it apart from a flat todo list. Confirmed by testing: right now, none of `children`/`dependencies`/`options` survive being written to a file and read back, so that structure can't actually be built yet. Tracked as `fix-list-field-roundtrip-1` in the project's own vex tasks — worth watching if the graph-based workflow is what drew you here.

### 2. Two people "assigning" work to each other

vex has no concept of users, notifications, or a server — and yet a small team can absolutely use it to hand work to one another, because the mechanism that makes this work is one they already have: **git**.

```txt
# Person 1 (Alice), in the shared repo
vex add Write the migration script --owner bob

git add . && git commit -m "assign migration script to bob" && git push
```

```txt
# Person 2 (Bob), after pulling
git pull
vex focus all --filter owner:bob
vex view tabular
```

`owner` isn't a specially-validated field yet (see the callout on [[02 Frontmatter schema]]) — it's a plain frontmatter key like any other, which is exactly why this already works: `vex add --owner bob` just writes `owner: bob` into the task file, and `--filter owner:bob` matches it back out. **The shared git repo is doing the syncing and the notifying; vex is just making sure the data underneath stays structured and diffable.** 
### 3. Spinning up a repeatable project skeleton

Kicking off a new milestone always means the same handful of tasks. Instead of retyping them, wrap them in a recipe once (see [[04 Configuring recipes]] for where this is headed, and the built-in `abstract` recipe for what exists today):

```txt
vex recipe abstract Launch the next milestone --status todo
```

and get a fully-formed parent task back (vex prints its vexid). Growing it into a full milestone by nesting the rest of the work under its `children` is the intent — not yet the reality, per the warning in example 1 above. As recipes become user-definable (currently code-only — see [[04 Configuring recipes]]) and the linking bug gets fixed, this is the shape of "one command, whole project scaffold."
