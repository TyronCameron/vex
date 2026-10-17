---
vexid: implement-cli-list-fields-1
vextype: task
description: Support list-typed fields as CLI flags
created: "2026-07-06 12:00:00"
modified: "2026-10-14 22:16:03"
status: done
---
Fixed for focuses: vex focus a,b,c works. from_comma_sep called a function that doesn't exist, and is now saved under its own name, so the prev focus replays it. Comma-separated list flags like --dependencies a,b are split out into their own task.