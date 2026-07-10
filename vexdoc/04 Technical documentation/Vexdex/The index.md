VexDex (`src/core/vexdex.lua`) is vex's index — conceptually the same role git's index plays: an in-memory map of `vexid → task data`, mirrored to disk so it doesn't have to be rebuilt from scratch on every run.

## On disk

Two things live under `.vex/vexdex/`:

- **`index.bin`** — the index itself, serialized with `binser` (a binary Lua-table serializer). This is what vex actually reads on startup.
- **`index.lua`** — a human-readable mirror of the exact same data, written with `pretty.write` alongside every binary write. It's never read back by vex — it exists so you can open it and see what the index contains without any tooling.
- **`focus.bin`** / **`focus.lua`** — the same binary+mirror pattern, but for your currently-saved [[01 CLI reference#Focuses|focus]] rather than the task index.

## Writes are atomic

Every write to `index.bin`, `index.lua`, `focus.bin`, or `focus.lua` goes through `VexDex:atomic`: it writes to a throwaway file in `.vex/tmp/` first (named from the current timestamp plus a random number), then `os.rename`s it into place. A crash or interrupted write can leave a stray file in `tmp/`, but it can't leave `index.bin` itself half-written.

## Loading and rebuilding

On first use in a project, `VexDex.new()` calls `ensureindex()`: if `index.bin` doesn't exist yet it starts from an empty index, otherwise it reads the existing one back in. Nothing incrementally verifies the index matches what's on disk in the task folder — that's what a full reindex is for:

```txt
vex resolve all
```

`resolve all` (`TaskManager:reindexall`, `src/core/task.lua`) clears the in-memory index entirely, walks every file under the project's `taskfolder` (see [[01 Configuring vex (config.lua)]]), reads and resolves each one it can parse as a task, and rebuilds the index from that — then writes it back out. This is the step to run after editing task files directly (by hand, by script, or by an AI agent) rather than through `vex add`/`vex set`, since nothing else notices those edits until something asks the index to catch up.

## See also

- [[Configuration]] — the config file VexDex's owning project reads (only `taskfolder` matters to VexDex directly).
- [[Plugin architecture]] — `sortdata`, `frontmatter`, and `taskformat` are the pluggable pieces VexDex depends on for reading/writing the tasks it indexes.
