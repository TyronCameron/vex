Every swappable piece of vex's behaviour — not just the on-disk file format, but id generation, path layout, sort order, and more — goes through the same small mechanism: `src/lib/plugin.lua`. This is real, working code, unlike most of the 03 Configuration section's extension points.

## Enums: named sets with one active member

`Plugin:addenum(name, members, active)` registers a **set** — a name paired with a list of possible implementations, exactly one of which is active at a time. `src/vex.lua` wires up the 7 sets vex currently has:

```lua
plugin:addenum("tagger", {"canonicalvexid"})
plugin:addenum("taskpath", {"flatpath"})
plugin:addenum("taskformat", {"obsidian"})
plugin:addenum("dataformat", {"csvdata"})
plugin:addenum("sortdata", {"canonicalsort"})
plugin:addenum("frontmatter", {"canonicalfrontmatter"})
plugin:addenum("body", {"canonicalbody"})
```

Each of these only has one member registered today, so in practice vex always runs with the default implementation of each — but the mechanism for having more than one and switching between them (`Plugin:select(set_name, member)`) is already there. **The task file format you've seen elsewhere in this wiki (markdown + YAML frontmatter) is just `taskformat`'s current — and only — member, `obsidian`.** Nothing about vex's task model depends on that specific format; a different `taskformat` plugin could serialize the exact same fields as JSON, SQLite rows, or anything else, and every other piece (schema, focus, views) would keep working unchanged.

## Resolution and fallback

`Plugin:get(name)` resolves an enum (or a plain plugin) to its module and lazily `require`s it:

```lua
-- src/lib/plugin.lua
local ok, mod = pcall(require, "plugin." .. name)
if not ok then
    mod = require("default." .. name)
end
```

So `plugin:get("taskformat")` first tries `src/plugin/obsidian.lua` and, only if that doesn't exist, falls back to `src/default/obsidian.lua` (where the real implementation actually lives today). This fallback is what lets `src/default/*` hold the reference implementation of every slot without every project needing a `src/plugin/*` override — a project only needs to add a file under `plugin.<name>` when it wants to *replace* the default, not to use it.

Also available: `Plugin:enable`/`Plugin:disable` (toggle a plugin off without unregistering it) and `Plugin:reload` (bypass Lua's `require` cache to hot-reload a plugin's module from disk).

## Plain plugins vs. enums

Not everything registered is part of a named set. `Plugin:add(name)` / `Plugin:addall(plugin_dir)` register standalone plugins — `src/vex.lua` calls `plugin:addall(script_dir .. '/plugin')` once, at startup, which is how `src/plugin/vexcomplete.lua` (the shell-completion commands — see [[01 CLI reference]]) gets loaded automatically. This is currently the *only* real plugin in `src/plugin/` — "Inline mode" and "Vexations" are referenced by `config.lua`'s default `plugins` table but have no corresponding files yet (see [[01 CLI reference]]'s "Planned / not yet implemented" section).

> [!NOTE] This only scans vex's own bundled folder
> `addall` is called once, against `src/plugin` — vex's own installation directory. There is currently no equivalent that scans a *project's* `.vex` folder for plugins, recipes, views, or focuses — see the 03 Configuration section ([[06 Configuring event hooks]], [[05 Configuring focuses]], [[04 Configuring recipes]], [[03 Configuring task types]], [[02 Configuring views]]) for the several extension points that are scaffolded (folders exist) but not wired up (nothing reads them) yet.

## Default implementations today

| Slot          | Default module                     | What it controls                                          |
| ------------- | ------------------------------------ | ------------------------------------------------------------ |
| `tagger`      | `default.canonicalvexid`            | Turns a description into a `vexid` — see the algorithm in [[01 CLI reference]]. |
| `taskpath`    | `default.flatpath`                  | Where a task's file lives on disk relative to `taskfolder`.  |
| `taskformat`  | `default.obsidian`                  | How a task's fields are serialized to and from a file.       |
| `dataformat`  | `default.csvdata`                   | The format the `csv` [[04 Views|view]] emits.                    |
| `sortdata`    | `default.canonicalsort`             | The field order used when printing frontmatter.               |
| `frontmatter` | `default.canonicalfrontmatter`      | How the frontmatter block is parsed out of a task file.       |
| `body`        | `default.canonicalbody`             | How the markdown body is parsed out of a task file.           |
