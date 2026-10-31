Every swappable part of vex, including id generation, file layout, the task file format and sort order, goes through one mechanism: `src/lib/plugin.lua`.

## Enums: named slots with one active member

`Plugin:addenum(name, members, active)` registers a slot: a name, the implementations that can fill it, and the one that is active. `src/vex.lua` registers six:

```lua
plugin:addenum("tagger", {"canonicalvexid"})
plugin:addenum("taskpath", {"grouppath"})
plugin:addenum("taskformat", {"obsidian"})
plugin:addenum("sortdata", {"canonicalsort"})
plugin:addenum("frontmatter", {"canonicalfrontmatter"})
plugin:addenum("body", {"canonicalbody"})
```

`Plugin:select(name, member)` switches the active member. The rest of vex depends only on the slot. Markdown with YAML frontmatter is simply what the `obsidian` member of `taskformat` writes; another member could store the same fields as JSON or database rows, and schemas, focuses and views would work unchanged.

| Slot | Default | Controls |
| --- | --- | --- |
| `tagger` | `default.canonicalvexid` | How a description becomes a vexid ([[01 CLI reference#Adding tasks]]). |
| `taskpath` | `default.grouppath` | Where a task file lives under `taskfolder`: flat, or nested by `paths.groupby` ([[01 Configuring vex (config.lua)]]). |
| `taskformat` | `default.obsidian` | How a task is written to and read from a file: `read(path)`, `render(frontmatter, body)` (the file's text) and `write(path, frontmatter, body)`. |
| `sortdata` | `default.canonicalsort` | The order of fields in the frontmatter. |
| `frontmatter` | `default.canonicalfrontmatter` | Which fields go in the frontmatter. |
| `body` | `default.canonicalbody` | Which field becomes the body. |

## Loading and fallback

`Plugin:get(name)` returns the active module, loading it on first use. It requires `plugin.<name>`, and falls back to `default.<name>` when there's no such module:

```lua
local ok, mod = pcall(require, "plugin." .. name)
if not ok then
    mod = require("default." .. name)
end
```

`src/default` holds the reference implementation for every slot. To replace one for every project, add a module of the same name to the `plugin` folder of your global folder (see [[01 Configuring vex (config.lua)#The global folder]]), which sits ahead of the install on Lua's module path and so survives upgrades.

## Standalone plugins

`Plugin:add(name)` and `Plugin:addall(dir)` register plugins outside any slot. At startup, `src/vex.lua` registers every file in `src/plugin`, then every file in the global `plugin` folder. A file named after an existing plugin or slot member is not registered again; it only changes which module gets loaded. That includes `vexcomplete`, which provides `vex autocomplete` and `vex suggest`, and the `vexations` and `inline` plugins.

`Plugin:enable` and `Plugin:disable` switch a plugin without unregistering it. `Plugin:reload` loads its module from disk again.
