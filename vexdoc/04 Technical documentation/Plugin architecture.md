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

`Plugin:select(name, member)` switches the active member to any registered plugin, including one shipped in a `plugin` folder of your own. A project does it from `config.lua`: `plugins = { tagger = 'shorttag' }` (see [[01 Configuring vex (config.lua)#Plugins]]). The rest of vex depends only on the slot. Markdown with YAML frontmatter is simply what the `obsidian` member of `taskformat` writes; another member could store the same fields as JSON or database rows, and schemas, focuses and views would work unchanged.

| Slot | Default | Controls |
| --- | --- | --- |
| `tagger` | `default.canonicalvexid` | How a description becomes a vexid ([[01 CLI reference#Adding tasks]]). |
| `taskpath` | `default.grouppath` | Where a task file lives under `taskfolder`: flat, or nested by `paths.groupby` ([[01 Configuring vex (config.lua)]]). |
| `taskformat` | `default.obsidian` | How a task file's text is parsed into a task (`parse`), rendered from one (`render`), and highlighted for `vex show` (`format`). It only handles text; vex reads and writes the files. |
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

`src/default` holds the reference implementation for every slot. To replace one, add a module of the same name to a `plugin` folder: `.vex/plugin` for one project, or the `plugin` folder of your global folder for all of them (see [[01 Configuring vex (config.lua)#The global folder]]). These sit ahead of the install on Lua's module path, the project's first, and the global one survives upgrades. To add a new member instead, put it in one of those folders under a new name and select it with `plugins = { slot = 'name' }`.

## Standalone plugins

`Plugin:add(name)` and `Plugin:addall(dir)` register plugins outside any slot. At startup, `src/vex.lua` registers every file in `src/plugin`, then every file in the global `plugin` folder and in the project's `.vex/plugin`. A file named after an existing plugin or slot member is not registered again; it only changes which module gets loaded. `src/plugin` holds `vexcomplete`, which provides `vex autocomplete` and `vex suggest`, and `vexations`, which registers the `abstract`, `decision`, `exploration` and `atom` task types, the `abstract` recipe and the abstract `status` and `phase` transients.

`Plugin:enable` and `Plugin:disable` switch a plugin without unregistering it: a disabled plugin is never loaded, so its verbs, task types and errors are not registered. `Plugin:reload` loads its module from disk again.

`Plugin:configure(settings)` applies the `plugins` table of `config.lua` to all of this at startup: `slot = 'plugin'` selects, `plugin = false` or `true` switches. It runs before `core.task` and `core.view` load, because they read the active members as they load. An unknown name, or a plugin that fills a slot being switched off, is the `bad-plugin-setting` error.
