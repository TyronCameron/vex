---
vexid: order-group-number-focuses-1
vextype: task
description: "Order, group and number focuses, with an urgency transient"
created: "2026-10-17 22:56:03"
modified: "2026-10-17 22:56:09"
status: done
---
Focuses had no way to order tasks or to rank them within a group, as SQL does with `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)`. `Focus:orderby(field[, desc]...)` sorts stably with missing values last. `Focus:groupby(field...)` splits a focus into groups that every later chained operation works within, and set operations gather them back. `Focus:rn()` numbers each group from 1 in `rn`. The `urgency` transient ranks each owner's open tasks by `due` with them.