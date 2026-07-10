---
vexid: implement-priorityorder-variables-1
vextype: task
description: Implement priority/order variables
created: "2026-07-10 22:13:20"
modified: "2026-07-10 22:13:20"
status: todo
---
Implement ordering variables which can have either or both of: 1) no gaps between orderings and 2) no ties between orderings

- Implement priority with no gaps and no ties

- `vex set my-task-1 --priority 3` sets the task to 3 and bumps everything higher; also, priority fails if there is a due date. Due date should fail if there is a priority. Priority is about urgency.

- Implement importance with no gaps and no ties