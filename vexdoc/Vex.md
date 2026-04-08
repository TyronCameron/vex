
## Philosophy 

Simple way to create and manage tasks, embeddable in any project, and local first. 

Tasks are just folders and markdown files. 

Focus on using the task management system to reduce uncertainty, make decisions, and create maximum efficiency sets of actionable items. 

Philosophy is to be minimalist, creating first a CLI tool which could be expanded into other tools. 

All written in luajit so it runs on a potato.

It is an opinionated tool, which can have bearing about how to think about about tasks, not just store them 

## Task types 

These types of tasks are opinionated and should be under a plugin called vexations

Four types of tasks. Users can create their own task types which are subtypes of the above, or subtypes of the master task type. 
Every task is a file. 

### 1. Exploration 
 A task to create the structures necessary for task decision and execution. 
 
- primarily about resolving an uncertain landscape into a certain landscape
- explorations are not loaded, they are the default state of any abstract until they are marked as explored. 
- the act of writing something down is a commitment to knowledge
	- actually not sure about this... Shouldn't they get a full task like the others so you can add content and outline? 
	- in fact I think they should get files for 2 reasons. 1. It lets us use outline view in obsidian to explore. 2. The argument against having them (being "how can unknown be known" is the same as "zero can't be a number"

These tasks ultimately have to answer: 

> What do I need to know? How can we accomplish the abstract? 

Every abstract creates an exploration task by default.  
Exploration tasks may also be useful in researching before writing documentation or committing to a path. 

The boundary is that we no longer create an exploration task when we know what to do within the entire scope of works (not what to do next). 

### 2. Abstract 

A parent task which can group child tasks together. Holds no/little information by itself. 
- primarily about creating a shell with structure which can be expanded on and decomposed later. 
- abstracts are created with the default add functionality, and are created very fast... Just jotted down 
- they are a .md file in and of themselves
	- when explored: if children, stay abstract. If no children, become a decision or atom or exploration. 

A warning will appear if an abstract ever has a body. It needs to be just YAML. 

An abstract just needs to ask: 

> What? 

Not how. Not why. 
When is a grey area for me. Would be good to pop on a date for quick tasks, but dependencies and that sort of thing need to go to children. Feels like a date might be better suited to an atom. 

### 3. Decision 

A task to resolve a decision, once the information has been laid out. Decisions can alter the landscape of tasks. 

- primarily about resolving alignment and decision making.  
- it is an if statement because it chooses which branch 
- or perhaps it can be a more abstract choice
- can collapse past of the tree structure 
- nothing wrong with the word "decision" either. 

A decision answers: 

> Which path to take?

Exploration tasks which find multiple solutions to the problem need a decision task. 
Naming conventions are decision tasks. 
Approval is a decision task. 
They absolutely can be dependent on other tasks. 

Decision feel like they're the way to capture: 
- Optional tasks (decide whether to continue)
- decision trees (if raining, bring umbrella)
- ors instead of ands for dependencies 

In fact, decisions should choose between tasks (task a, task b, task c). Decisions therefore are the only place which encode reachability. 
Note that they allow ORs in one sense but not another. 
You could achieve your goal by following path A or path B. A decision is for that. 

I wrote this which I think I agree with: 

I'm starting to think that maybe a decision task is a "folder" of tasks (sum type) which a choice. 
So we have: 

atom: spoon coffee
-> 
decision {add-sugar, skip} 
-> 
atom: add hot water 
-> 
(add-sugar ->) add-milk

### 4. Atom 

Afully executable action which is fully known, can be done by one person only. 

- primarily about getting stuff down 
- structure in dependencies between atoms 

atoms, decisions, and explorations are chained together into dependency graphs (DAGs). There are the following shapes only: 
- a then b (dependent)
- a with b (independent) (i.e. unspecified)
- a then b after c (collider)
- a after b then c  (branch)

Abstracts and the other task types are related through a parent-child tree structure

A user can then create their own task types which inherit from these task types, and which perhaps have specific fields or information. 

## File structure 

Every task is a .md file with YAML frontmatter. 

In the config file in .vex users will be able to specify the root folder for all the files. 

Everything needs a vex: ID property which internally represents the identity of the item. 

We expect no body for an abstract, and vex will continuously warn a user to put that information in an exploration by default. 

We expect parents for leaf nodes and those parents are always abstracts. 
We expect a DAG structure for leaf nodes and those are never abstracts (unless we want a shorthand for "all" which I think we shouldn't have...). 

The user can choose how they like their files being arranged on disk by choosing the folders. They can do something like this: 
+ Group by: status
+ Group by: owner 
+ Or combos
+ other available options:
	+ Parent 
	+ Created date 
	+ Priority 
	+ Due date 
So on and so forth. 

Vex needs to know how to move files around anyway, and I think it will do so with a temp folder created in .vex and then moved to the root folder. 

## Statuses

There are 3 main statuses: 
- todo (inactive before doing)
- doing (active)
- done (inactive after doing)

Users can create new statuses for their tasks, which are subtypes of the above. 





## Watch mode / plugin 

Instead of adding in tasks via CLI, it may sometimes be better to link information directly in files. Can add something like this to a file. 

#vex Description

When vex is invoked it will then link through the ID in this spot so it can keep track of the path. 

It will become #abstract/ABC-123[[path]]

This means that: 
- exploration tasks can be done in an outliner 
- you can add in task references to any source file (e.g. code) anywhere, including abstracts

In addition you could do: 
- #abstract same as vex.
- #atom instead of abstract to promote it 
- #explore to load an exploration task 
- #decision to load a decision task 

Those tasks would link back to the exact spot in code. In addition, changing names or any other details would auto resolve in code as well as in tasks.

Sub indentation either becomes: 
- sub abstract tasks 
- or detail under the atom / explore / decision 

Consider: 
#vex/atom ... = vex atom ...

Allow flags. So identical to CLI language. 


## validation  

Vex will validate tasks and warn users by default 


## Config folder
In the .vex config folder it is envisioned that we have: 
- config.lua for global config
- templates - for task type templates, which allows you to create individual tasks straight away (e.g. atoms) or entire folders of tasks (including decision options in them). This creates workflows.
- plugins - code which can be used to extend functionality
- hooks - on_resolve = function(task) ... end
- tmp - for temp folder restructures
- views


Config.lua allows for: 
- inheriting config, templates, plugins, etc. from parent or global config 
- setting root folder where the tasks themselves are actually stored 
- folder structure types (choosing paths)
- task name structure (default = tag)
- allow hooks: true/false
- file format
- warnings on/off 
- default views 


## Plugins 

Each plugin is a folder, with an init file. 
Default behaviour shouldnt be a plugin, but there should be a key place to replace core behaviour. 

E.g. in core.lua, cannot 
tag = require 'tag'
But rather should 
plugin = require 'plugin'
config = require 'config' 
config.load() -- sets metatable to default paths
tag = plugin.require(config)

Vexations
Watch mode 
File format
- obsidian.md
Query 
- vexQL
Query format
- CSV 
- JSON 
Views 
- tabular 
- kanban 
Export to .ics
Tag creation (i.e. how to create naming from a description)
Pushback mode from LLM

## Schedules 

Abstracts can have schedules attached to them which cover an interval of time (or a union of intervals)
Atoms can have dates attached to them (e.g. due dates)

Other dates include: 
- status dates
- created dates
- modification dates 
- commit dates

## Nesting

You can have .vex folders in projects, but you should also be able to view across projects.
That may imply that nesting .vex under a .vex is acceptable? 
This may imply for consistency that you should be able to set up an array of todo folder paths in your config. 


## Fields

Need a preprocessor on every field. That preprocessor can take what's in the field, and the rest of this task, and the task manager in as args. 
Combined with default fields, this allows us to create fully derived fields (e.g. date created) .. actually there are 2 types of derived fields: 
1. Derive when storing data and stamp it into place
2. Derive when accessing the data, and keep it always up to date. I don't think this one is possible because we may view the task outside of vex. 
I think things like "is abstract done" should be a derived field of type 1 where resolve updates it. Once updated, it's always updated. 

For example, parents must always link to another file (& validate single parent). So must dependencies (& validate no cycles). Due dates are converted into a standard date. 
Cannot have priority and due date in my opinion. Can have urgency & importance though. 
Status will check the statemachine. I want status to have a full statemachine even though vexations will only use simple linked lists. Status is a separate concern to options, because it marks whether or not a decision has in fact been made. 

## Code plan

src
- main.lua (global config, load plugins)
- lib 
	- plugin (manager)
	- config (manager)
	- pretty 
	- serialization
	- statemachine
	- dag 
	- tree
	- events
	- optic
- core
	- task (manager) 
	- recipe (manager)
	- init (as in vex init)
	- index (manager)
	- cli (+load extensions from plugins)
	- resolve
	- focus
- default
	- status-view
	- query-format
	- disk-format
	- query-lang
	- tag-names
	- open
- plugins
	- watch-mode
	- vexations
	- folderize (hooks into resolve)