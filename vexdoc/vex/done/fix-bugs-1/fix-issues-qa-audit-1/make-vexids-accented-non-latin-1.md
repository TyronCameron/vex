---
vexid: make-vexids-accented-non-latin-1
vextype: atom
description: Make vexids from accented and non-Latin descriptions
created: "2026-11-10 11:00:43"
modified: "2026-11-10 11:00:43"
status: done
---
`canonicalvexid` matched words with ASCII-only `%w`, so `Café crème für Jürgen` became `caf-cr-f-r-j-rgen-1` and CJK text became `task-1`. Latin accents now fold to ASCII, other scripts' letters are kept, curly apostrophes and dashes read as plain ones, and the 32-character budget counts characters.