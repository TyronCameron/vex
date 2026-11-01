---
vexid: check-file-mtime-listing-macos-1
vextype: atom
description: Check file mtime listing on macOS and Windows
created: "2026-10-31 04:50:58"
dependencies: 
  - "[[detect-task-files-changed-disk-1]]"
modified: "2026-10-31 04:51:03"
status: todo
---
`lfsext.mtimes` and `lfsext.mtime` (`src/lib/lfsext.lua`) use GNU `find -printf`, which is tested. On BSD/macOS they fall back to `find -exec stat -f '%Fm%t%N'`, and on Windows to PowerShell `LastWriteTimeUtc.Ticks`; neither is tested. On Windows the listed paths must also match `TaskManager:getcurrentpath` (backslashes, drive letters), or every file looks updated on every command. Run `test/unit/lib/lfsext_spec.lua` and `test/e2e/storage_spec.lua` on both and fix whatever fails. Related to [[check-grouped-task-paths-windows-1]].