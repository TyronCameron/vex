
local func = require 'lib.func'
local plugin = require 'lib.plugin'
local tagger = plugin:get 'tagger'
local taskpath = plugin:get 'taskpath'
local taskformat = plugin:get 'taskformat'
local sortdata = plugin:get 'sortdata'
local frontmatter = plugin:get 'frontmatter'
local body = plugin:get 'body'
local cli = require 'lib.cli'
local lfs = require 'lib.lfs'
local focus = require 'core.focus'

local Task = {}
Task.__index = Task

-- creates new task manager
function Task.new(vexdex, config)
    return setmetatable({
        vexdex = vexdex,
        tasktypes = {task = {}},
        tasks = {},
        config = config
    }, Task)
end

-- registers task type
function Task:vextype(name)
    return function(tab)
        self.tasktypes[name] = tab
    end
end

-- vextype 'abstract' {

-- }

---------------------------------------------------
-- Public API
---------------------------------------------------

-- creates new task
function Task:add(task)
    assert(task and type(task) == "table", "add() requires a table of task properties")
    assert(task.description, "task must have a description to be added")
    task.vexid = tagger.generate(task.description, self.vexdex.index)
    task.vextype = task.vextype or "task"
    task.created = os.time()
    task.modified = task.created
    task.status = task.status or "todo"
    task.vexbody = ""
    local existing_task = self:getsingle(task.vexid)
    if existing_task then cli:throw('task-already-exists', task.vexid, existing_task.path) end 
    self.tasks[task.vexid] = task
    return task.vexid
end

-- removes task by id or focus
function Task:remove(vexid)
    assert(vexid, "remove() requires an id or focus")
    self.tasks[vexid] = nil
    return vexid
end

-- gets data from a task and returns it as a string for the command line
function Task:getstring(vexid)
    local t = task:getsingle()
    local values = {}
    for _, pair in ipairs(func.ifilter(args, function(word) return type(word) == "table" end)) do
        table.insert(values, t[pair[1]])
    end
    return table.concat(values, "\n")
end

-- sets task properties for a given focus
function Task:set(vexid, tab)
    assert(tab and type(tab) == "table", "set() requires a table")
    local task = self:getsingle(vexid) 
    for k,v in pairs(tab) do 
        assert(k ~= "vexid", "Cannot change the vexid with set")
        task[k] = v
    end
    task.modified = os.time()
    return task 
end

-- shows task, basically cat 'filename'
-- prints a task's contents to stdout
-- if the focus results in more than one task, will print them all
function Task:show(vexid)
    assert(vexid, "show() requires an vexid")
    local task = self:getsingle(vexid)
    local path = '' 
    if task.path then path = ' (' .. task.path .. ')' end 
    print('# ' .. task.vexid .. path)
    print("---")
    for k, v in sortdata(frontmatter(task)) do 
        print(k .. ": " .. v)
    end 
    print("---")
    print(body(task))
end

-- views a list of tasks with a specific view
-- example focus = "not-done"
-- example view = "table" or "kanban"
function Task:view(focus, view)
    focus = focus or "prev"  -- default to previous focus
    view = view or "table"   -- default to table view
    
    -- Get tasks matching focus
    -- Apply view formatting
end

---------------------------------------------------
-- Resolution
---------------------------------------------------

-- resolution: validates, updates and normalises fields and tasks
-- includes:
-- - data validation (misspellings, invalid values)
-- - data enrichment (creation date, time, auto-fields)
-- - data normalisation (convert "tomorrow" to actual date)
-- - path checking and resolving links
-- - tag duplication checks
-- should always add to index at the end of a resolve, possibly already removing the task


-- recursively walk dir to get all vexids. 
local function get_all_vexids(path, tasks)
    tasks = tasks or {}
    for _, file in lfs.readdir(path) do
        if lfs.isdir(file) then  
            get_all_vexids(file, tasks)
        else
            table.insert(tasks, file:gsub("%..*$", ""))
        end
    end
    return tasks
end

-- rebuild the entire vexdex by iterating through the filesystem
function Task:refreshall()
    for key in pairs(self.vexdex.index) do
        self.vexdex:unsafe_remove(key)
    end
    local vexids = get_all_vexids(self.vexdex.path)
    for _, vexid in ipairs(vexids) do
        self:read(vexid)
        self.vexdex:unsafe_add(vexid, self.tasks[vexid])
    end
    self.vexdex:writeindex()
    return self 
end

local function validate(vextype, task)
    return true 
end 

local function derive(vextype, task)
    return true 
end 

local function normalise(vextype, task)
    return true 
end 

local function link(vextype, task)
    return true 
end 

-- adds it to the index
function Task:index(vexid)
    self.vexdex:add(vexid, self.tasks[vexid])
end

-- removes from the index
function Task:unindex(vexid)
    self.vexdex:remove(vexid)
end

-- resolve
function Task:resolve(vexid)
    assert(type(vexid) == "string", "This is not a vexid")
    local task = self:getsingle(vexid)
    if not task.vextype then cli:throw('missing-required-field', vexid, 'vextype') end 
    local vextype = self.tasktypes[task.vextype]
    if not vextype then cli:throw('unknown-vextype', vextype, func.keys(self.tasktypes)) end 

    if not validate(vextype, task) then cli:throw('resolution-failed-validation', vexid) end 
    if not derive(vextype, task) then cli:throw('resolution-failed-derivation', vexid) end 
    if not normalise(vextype, task) then cli:throw('resolution-failed-normalisation', vexid) end 
    if not link(vextype, task) then cli:throw('resolution-failed-linking', vexid) end 

    self:index(vexid)
end

---------------------------------------------------
-- Tasks and focuses
---------------------------------------------------

-- Get a table of tasks 
function Task:gettasks(focus)
    
end

-- gets single task by id
-- first attempts to get it from the index, but then tries reading it 
function Task:getsingle(vexid)
    assert(vexid, "getsingle() requires an id")
    self.tasks[vexid] = self.tasks[vexid] or self:read(vexid)
    return self.tasks[vexid]
end

-- converts an id list to a focus representation
-- allows composable focuses from id lists
function Task:to_focus(tasks)
    if tasks.id then return {tasks} end 
    return tasks 
end

---------------------------------------------------
-- File I/O
---------------------------------------------------

-- this needs a bit of work. This should: read from tasks if available in memory, or fall back to checking the index, or attempt to generate a path with a nothing task in it
-- it should not use getsingle which depends on read, which depends on this. 
-- This should be the source of truth everywhere.
-- it should probably also allow passing the full task manager through so you can iterate through it nicely 
function Task:getpath(vexid)
    local task = self:getsingle(vexid)
    return taskpath.path(self.config, self.vexdex.path .. '/' .. self.config.taskfolder, task)
end

-- reads a file from disk and adds it to memory
function Task:read(vexid)
    local staletask = self.vexdex:get(vexid) or {}
    staletask.vexid = vexid
    local ok, task = pcall(taskformat.read, taskpath.path(self.config, self.vexdex.path .. '/' .. self.config.taskfolder, staletask))
    if ok and task then 
        self.tasks[task.vexid] = task
        self:index(task.vexid)
        return task
    else 
        return nil 
    end
end

-- writes a file from disk
-- should mkdir if needed
function Task:write(vexid)
    local task = self:getsingle(vexid)
    local str = taskformat.write(self:getpath(vexid), sortdata(frontmatter(task)), body(task))
    self:index(vexid)
    return vexid
end

-- deletes a file from disk
function Task:delete(vexid)
    os.remove(self:getpath(vexid))
    return vexid
end

return Task