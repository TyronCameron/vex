---
vexid: group-task-files-into-1
vextype: task
description: Group task files into folders
created: "2026-10-15 00:45:00"
modified: "2026-10-15 00:45:00"
status: todo
---

Arrange task files into nested folders by a configurable list of groupings, e.g. `groupby = {'parent', 'status'}` in `.vex/config.lua`. `parent` nests a task under its ancestor chain (through `children`). Any other name groups by that field's value (`status`, `owner`, ...). Spiked as the `grouppath` taskpath plugin. Without `groupby` the paths stay flat.

How the spike works:

- `grouppath` computes where a file *should* live from the vexdex index (`Focus:reversetree('children')` gives the parent chain).
- `vexdex.paths` records where each file *does* live, so `TaskManager:read` no longer has to derive the path from the vexid.
- `TaskManager:write` writes in place, then moves the task and its descendants (`Focus:tree('children')`).
- `TaskManager:delete` moves a removed task's subtree back up.
- `vex resolve all` moves every file to where it belongs, which also migrates an existing flat folder.

Dragons:

1. The path no longer derives from the vexid. A read uses the recorded location (`vexdex.paths`). If the file isn't there, vex looks for its filename anywhere in the taskfolder and records where it found it. That walk costs a directory scan on every miss, including `vex add`'s check for an existing task.
2. The parent is a backlink, not a field: a child's path changes when *another* task (its parent) is written. Parents are often created after their children, or hand-edited in Obsidian.
3. Cascades. Moving a parent moves its whole subtree, and removing a parent moves its children back up. The `vexlink` backlink cascade doesn't cover this, because children don't link to their parent.
4. Nesting needs exactly one parent. `singleparent` enforces that today, but [[create-milestones-1]] already questions it.
5. `children` has no cycle check (`acyclic` only guards `dependencies`). `optic.traverse` won't loop forever, but the path would depend on where the walk started.
6. Hand moves. A file dragged around in Obsidian is found again, but the next write or `vex resolve all` moves it back. Should a hand move instead change the field it implies (e.g. dragging into `doing/` sets the status)?
7. Moves are not atomic as a group. A crash mid-cascade leaves a half-reorganised tree. A crash between writing the new file and removing the old one could leave two files with the same vexid.
8. Folder names come from values. Owners, dates (epochs in memory), lists, values containing `/`, and unset values all need a policy. The spike uses `tostring` and skips unset values.
9. Churn. Grouping by status renames the file on every transition: git history, open Obsidian tabs and diffs all suffer. `[[vexid]]` links survive because filenames stay unique.
10. Empty folders. The spike removes emptied folders up to the taskfolder with `os.remove`. `lib/lfs.rmdir` is `rm -rf` and must not be used for this.
11. The taskpath plugin now depends on the index, so a path is only right after the task has been resolved.
12. Folder and file focuses now work (`vex show todo/`, `vex focus todo/x.md`). They only trigger when the name contains a `/`.
13. `owner` isn't a real field yet ([[implement-owner-assignment-1]]).
14. Config can't select plugins ([[make-config-actually-control-1]]), so `grouppath` is the active taskpath and stays flat without `groupby`.
