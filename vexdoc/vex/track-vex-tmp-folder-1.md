---
vexid: track-vex-tmp-folder-1
vextype: task
description: Track vex tmp folder in git
created: "2026-10-13 22:14:55"
modified: "2026-10-13 22:14:55"
status: todo
---

`VexDex:atomic` writes every index, focus and task update to `.vex/tmp/<random>.txt` and then renames it into place. Git doesn't track empty folders, so a fresh clone of this repo has no `.vex/tmp/`, and the first write fails with "Could not write file intended for .../index.bin". It looks like a write error but is only a missing folder.

Options: track the folder with a `.gitkeep` (plus a `.gitignore` for its contents), or have `VexDex:atomic` (or `VexDex.new`) create `tmp/` when it's missing. The second option also protects user projects whose `.vex` was copied without it.
