
local func = require 'lib.func'
local plugin = require 'lib.plugin'
local tagger = plugin:get 'tagger'
local taskpath = plugin:get 'taskpath'
local taskformat = plugin:get 'taskformat'
local cli = require 'lib.cli'

local Task = {}
Task.__index = Task

-- creates new task manager
function Task.new(vexdex, config)
    return setmetatable({
        vexdex = vexdex,
        tasktypes = {},
        tasks = {},
        config = config
    }, Task)
end

-- registers task type
function Task:tasktype(name)
    return function(tab)
        self.tasktypes[name] = tab
    end
end

-- adds it to the index
function Task:index(vexid)
    self.vexdex:add(vexid, self.tasks[vexid])
end

-- removes from the index
function Task:unindex(vexid)
    self.vexdex:remove(vexid)
end

-- creates new task
function Task:add(task)
    assert(task and type(task) == "table", "add() requires a table of task properties")
    assert(task.description, "task must have a description to be added")
    task.vexid = tagger.generate(task.description, self.vexdex.index)
    task.tasktype = task.tasktype or "task"
    task.created = os.date("%Y-%m-%d") .. ":" .. os.time()
    task.status = task.status or "todo"
    task.vexbody = ""
    local existing_task = self:getsingle(task.vexid)
    if existing_task then cli:throw('task-already-exists', task.vexid, existing_task.path) end 
    self.tasks[task.vexid] = task
    return task.vexid
end

-- removes task by id or optic
function Task:remove(vexid)
    assert(vexid, "remove() requires an id or optic")
    self.tasks[vexid] = nil
    return vexid
end

-- sets task properties for a given optic
function Task:set(vexid, tab)
    assert(tab and type(tab) == "table", "set() requires a table")
    local task = self:getsingle(vexid) 
    for k,v in pairs(tab) do 
        assert(k ~= "vexid", "Cannot change the vexid with set")
        task[k] = v
    end
    return task 
end

-- gets single task by id
-- returns a single task's data
function Task:getsingle(vexid)
    assert(vexid, "getsingle() requires an id")
    self.tasks[vexid] = self.tasks[vexid] or self:read(vexid)
    return self.tasks[vexid]
end

-- this needs a bit of work. This should: read from tasks if available in memory, or fall back to checking the index, or attempt to generate a path with a nothing task in it
-- it should not use getsingle which depends on read, which depends on this. 
-- This should be the source of truth everywhere.
-- it should probably also allow passing the full task manager through so you can iterate through it nicely 
function Task:getpath(vexid)
    local task = self:getsingle(vexid)
    return taskpath.path(self.config, self.vexdex.path .. '/' .. self.config.taskfolder, task)
end

-- get data only (no body)
function Task:getdata(vexid)
    local data = {}
    for k,v in pairs(self:getsingle(vexid)) do
        if k ~= "vexbody" then 
            data[k] = v
        end 
    end
    return data
end

-- get body only (no data)
function Task:getbody(vexid)
    return self:getsingle(vexid).vexbody
end



-- shows task, basically cat 'filename'
-- prints a task's contents to stdout
-- if the optic results in more than one task, will print them all
function Task:show(optic)
    assert(optic, "show() requires an optic")
    
    -- Get task(s) matching optic
    -- Print their contents
end

-- views a list of tasks with a specific view
-- example optic = "not-done"
-- example view = "table" or "kanban"
function Task:view(optic, view)
    optic = optic or "prev"  -- default to previous optic
    view = view or "table"   -- default to table view
    
    -- Get tasks matching optic
    -- Apply view formatting
end

-- resolution: validates, updates and normalises fields and tasks
-- includes:
-- - data validation (misspellings, invalid values)
-- - data enrichment (creation date, time, auto-fields)
-- - data normalisation (convert "tomorrow" to actual date)
-- - path checking and resolving links
-- - tag duplication checks
-- should always add to index at the end of a resolve, possibly already removing the task
function Task:resolve(optic)
    assert(optic, "resolve() requires an optic")
end

-- converts an id list to an optic representation
-- allows composable optics from id lists
function Task:to_optic(tasks)
    if tasks.id then return {tasks} end 
    return tasks 
end

-- reads a file from disk and adds it to memory
function Task:read(vexid)
    local staletask = self.vexdex:get(vexid) or {}
    staletask.vexid = vexid
    local ok, task = pcall(taskformat.read, taskpath.path(self.config, self.vexdex.path .. '/' .. self.config.taskfolder, staletask))
    if ok then 
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
    local str = taskformat.write(self:getpath(vexid), task)
    return vexid
end

-- deletes a file from disk
function Task:delete(vexid)
    os.remove(self:getpath(vexid))
    return vexid
end

return Task