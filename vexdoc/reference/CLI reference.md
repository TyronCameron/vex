## Global conventions

## Command list

In the table below `monosopaced` values are arguments. Arguments starting with a capital letter are allowed to be multiple words long.

### Core commands

| **Command**                               | **Description**                                                                                             |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| vex help                                  | Provides a list of commands and descriptions                                                                |
| vex init                                  | initialises a .vex directory in the current directory                                                       |
| vex show \[`optic`]                       | prints a task's contents to stdout. If the optic results in more than one task, will print them all.        |
| vex optic \[`optic`] \[flags...]          | creates an optic which can be used as a data query against the vex folder. More details in a section below. |
| vex view \[`optic`] \[`view`] \[flags...] | prints a view of current tasks.                                                                             |
| vex resolve \[`optic`]                    | validates, updates and normalises fields and tasks                                                          |
### Editing tasks

| **Command**                       | **Description**                                                                                                                                         |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| vex add `Description` \[flags...] | Creates a task with the `Description` provided. Automatically fills out some frontmatter and resolves. This outputs and sets the optic to this new tag. |
| vex remove \[`optic`]             | Deletes tasks in the optic. Runs resolve on all linked tasks thereafter. Not recommended for regular use.                                               |
| vex get \[`optic`] \[flags...]    | Presents the optic in a tangible data format. Can specify which fields by supplying them as flags.                                                      |
| vex set \[`optic`] \[flags...]    | Allows you to set fields in the optic. Resolution is called on that `optic`.                                                                            |
| vex recipe `recipe`               | Creates a recipe (series of tasks). This outputs and changes the optic.                                                                                 |
### Inline mode (plugin)

| **Command**          | **Description**                                     |
| -------------------- | --------------------------------------------------- |
| vex open \[`optic`]  | Opens the task in the editor of your choice.        |
| vex inline \[`path`] | Read a file and use inline vex tags to create tasks |

### Vexations (plugin)

| **Command** | **Description** |
| ----------- | --------------- |
|             |                 |

## Discussion of commands

### Initialisation 

Initialising a folder creates a `.vex` directory in the working directory. Inside that directory, the following things are stored: 

- An index 
- A `config.lua` file which you can change to influence vex behaviour 
- A `tasks` folder which allows you to create new tasks 
- A `recipes` folder which allows you to create new recipes
- An `optics` folder for named optics
- A `views` folder which allows you to create new views
- An `events` folder which allows you to add hooks to certain events. 

If you do not initialise a folder before using vex, vex will look at parent directories for a `.vex` folder. 

> [!NOTE] Global vex
> If you wish for a global .vex folder, there is nothing stopping you from creating one in your home folder, and using its config to point to any directory of your choosing. 

### Optics

Optics are data tools. They are named as such because they are a lazy composable way to create getters and setters of data, and they are used in a large number of vex commands.

In order to query your data, you need to create an optic and pass it through to a `vex get` command. For example: 

```txt
vex optic --filter status:done | vex get
```

`vex get` provides a data format which is usable for other programs, such as a CSV. You could therefore pipe this query to `duckdb` or another data tool of your preference. 

They are composable in the sense that you can write either of these with the same meaning: 

```txt
vex optic --filter due:2030-01-01 --select id,tag,due,description 
```
OR: 

```txt
vex optic --filter due:2030-01-01 | vex optic --select id,tag,due,description
```

Named optics: 
- `prev` which saves the previous optic used. For conciseness, this is the default optic. If no `prev` is available, it uses `none` instead. This applies in all cases except for `optic` itself. 
- `all`
- `none`
- `tag` for any task tag 
- `path` for any task path (if there is a slash)
- `updated` for only tasks which have updated against the index. 
- comma separation of the above is allowed so as to union them

Flags: 
- `--select comma-sep-fields`: gets just those fields 
- `--filter field:value`: filters list downwards 
- `--fuzzy field:value`: filters list fuzzily 
- `--between field:begin:end`: filters for a value between `begin` and `end`. Leaving out `begin` will do less than or equal `end`. Leaving out `end` will do more than or equal to `begin`. 
- `--tree field`: walks the tree over that field. 
- `--reversetree field`: walks a reverse tree over that field. 
- `--dag field`: walks a DAG over that field. 
- `--reversedag field`: walks the reverse dag over that field 
- `--interpret` before any flag will convert values where possible. E.g. `--interpret --filter due:tomorrow` will check for tasks due tomorrow.
- `--or` before a filter unions to the list. 

All flag commands run in the order provided.

Mapping and folding is reserved for optics in Lua rather than through the CLI. 

You can create new named optics by adding files to the `optics` subdirectory of your `.vex` folder. 

### Views

Views are ways to gain high level summaries of all tasks, such as through (non-interactive) tables or kanban boards. 

You can create new views by creating Lua files in the `views` subdirectory of your `.vex` folder. 

You can override the default view by editing your `config.lua` file. 

Views live on top of optics in the sense that they can accept any optic and attempt to provide a view of the tasks hooked into that optic. 

### Resolution 

Resolution is what vex does to check data correctness. Resolution includes the following steps: 
- Data validation. If a misspelling occurs, resolution can throw an error. For example: `vex add Do dishes --due tomorro` will fail. It can also warn if it finds a validation error on an existing task (perhaps edited with another tool). 
- Data enrichment. When a task is created or updated, certain fields (such as creation date and time) maybe be added to the task. 
- Data normalisation. When you add `--due tomorrow`, the date of `tomorrow` will be added to the task, rather than the text
- Path checking and resolving links. Paths are checked to ensure they still exist. If they do not, vex will search for the new paths to those files. This can be an expensive operation but is not always needed. 
- Tag duplication checks, which can result in undefined vex behaviour. Again, expensive but not always needed. 

Resolution is a safe way to ensure data integrity and consistency. However, it does not protect against editing with other tools, which is why resolution is presented as a command you can invoke. 

You can add a `vex resolve all` hook to your `git pre-commit` or PR pipelines to check for integrity. 

Resolution rules can be extended in your `tasks` subdirectory of your `.vex` folder. 

### Adding new tasks

You can add a new task as follows

```txt
vex add Make coffee for wife --due morning 
```

This will create a new task in the `taskfolder` specified in the `config.lua` file. 

If you use the built-in folderize plugin, this may be automatically filed away in a subdirectory based on its attributes. 

This new task will have the tagger run over it and may get a file name like "make-coffee-wife". Tags are unique per `vex` project. 

Tags are by default generated by: 
- slugging all words together
- keeping a maximum of 4 keywords, prioritising at least one verb 
- if duplicated, it appends a number

Adding a task outputs the tag to the screen. 

Arbitrary fields can be passed to vex, and it will put it into the frontmatter of the task. `--due` happens to be a recognised field which has resolution hooks. Upon resolving, "morning" will be converted to a date. 

By ensuring the `--tasktype` flag is passed, we can choose how resolution runs on this task. 

### Editing existing tasks

You can use `set` to edit tasks. 

For example: 

```txt
vex set make-coffee-wife --importance very-high --parent wifely-business
```

This will set the fields provided. Resolution is run on this task, and as such it will check that `very-high` is valid and that `wifely-business` exists, and if it does, it will convert it to a link. 

You can pass arbitrary fields and values using a `set` operation. 

### Recipes

You can create recipes which are series of tasks. 
You can create new recipes by adding files to the `recipes` subdirectory of your `.vex` folder. 



 







### Inline mode

### Vexations

