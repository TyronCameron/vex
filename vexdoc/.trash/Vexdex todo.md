Good choice — binser is compact and fast to deserialise back into a native Lua table, which means your index is just a table in memory the moment you load it. No query layer, no schema, just `index[vexid]`.

The main thing to watch is **atomic writes**. Since it's a single file, a crash mid-write corrupts your entire index. The standard mitigation is write-to-temp-then-rename:

```lua
local tmp = ".vex/index.tmp"
local f = io.open(tmp, "wb")
f:write(binser.serialize(index))
f:close()
os.rename(tmp, ".vex/index")
```

`os.rename` is atomic on Linux/macOS (POSIX rename semantics), so you never have a window where the index is partially written.

The other thing worth thinking about is **index rebuild**. Since the index is derived from the task files, you should be able to reconstruct it by scanning `.vex/` and re-parsing frontmatter. A `vex index rebuild` command (or automatic rebuild on corruption detection) makes the index feel safe rather than precious — if something goes wrong, it's recoverable. Binser has no built-in integrity check, so you might want a version field and a checksum (or just a magic header) so you can detect corruption on load rather than getting a cryptic deserialise error.

The edge list for the graph is worth adding now while the format is still fresh — it's trivial to include and saves you from a format migration later.