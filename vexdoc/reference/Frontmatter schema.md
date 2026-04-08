## Mandatory fields

| **Property** | **Type** | **Description**                                                                         |
| ------------ | -------- | --------------------------------------------------------------------------------------- |
| vexid        | text     | A unique ID internally. By default, is the filename.                                    |
| tasktype     | text     | The type of task it is. Default "task".                                                 |
| description  | text     | A reasonable length description of the task itself. Mandatory for tasks of type "task". |
| status       | text     | The current status of the task.                                                         |
### Optional fields

| **Property** | **Type** | **Description**                     |
| ------------ | -------- | ----------------------------------- |
| start        | datetime | The planned start date of the task. |
| due          | datetime | The planned due date of the task.   |
| priority     | int      | Priority ordering of the work.      |
| owner        | user     | Who is doing the tasks.             |
| parent       | link     | Parent task                         |
| depends-on   | links    | Dependency tasks                    |
| options      | links    | List of possible tasks              |
| choice       | link     | Single task                         |
Plus anything else a user might want to add. 