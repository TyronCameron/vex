---
vexid: stop-spawning-shell-file-1
vextype: atom
description: Stop spawning a shell per file operation
created: "2026-10-31 06:40:16"
modified: "2026-10-31 06:40:29"
status: done
---
src/lib/lfs.lua is a shim that runs a shell command for every call: TaskManager:write ran mkdir -p for every written task even when its folder existed (1,120 processes for one hub set at 1.45k tasks), and lfsext.walk ran stat for every file (1,068 processes for resolve all over 1k tasks). Fixed: lfs.mkdir returns early for an existing folder and walk lists the tree with one find outside Windows.