---
vexid: show-traceback-internal-errors-1
vextype: task
description: Show traceback in internal errors
created: "2026-10-15 13:05:06"
modified: "2026-10-16 02:05:04"
status: done
---
Found by the new cli unit test. `CLI:call` (`src/lib/cli.lua`) builds the `bug` error's trace with `debug.traceback(nil, 2)`, which returns nil in LuaJIT and Lua 5.1 (a nil message means no traceback is produced). So every "Internal error" is printed without its traceback, which hides where the crash happened. Passing a string message (e.g. `debug.traceback("", 2)`) fixes it.