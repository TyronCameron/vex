
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
local lfsext = require 'lib.lfsext'
local pretty = require 'lib.pretty'
local vexdex = require 'core.vexdex'
local config = require 'core.config'

------------------------------------------------
--- Tasks
------------------------------------------------

local Task = {}
Task.__index = Task

-- construction
function Task.new(task)
    assert(type(task) == "table", "A task must be a table of information")
    assert(task.vexid, "A task must have a vexid")
    return setmetatable(task, Task)
end

-- gets data from a task and returns it as a string for the command line
function Task:tostring(fields)
    local values = {}
    for _, pair in ipairs(func.ifilter(fields, function(word) return type(word) == "table" end)) do
        table.insert(values, self[pair[1]])
    end
    return table.concat(values, "\t")
end

-- show 
function Task:show(path)
    local final_str = pretty.string('# ' .. string.upper(tostring(self.vexid)) .. '\n', 'cyan', 'underline', 'bold', {filelink = tostring(path)})
    final_str = final_str .. pretty.string("---\n", 'cyan')
    for k, v in sortdata(frontmatter(self)) do 
        final_str = final_str .. pretty.string(tostring(k) .. ": ", 'green') .. pretty.string(tostring(v or '') ..  '\n')
    end 
    final_str = final_str .. pretty.string("---\n", 'cyan')
    final_str = final_str .. pretty.string(tostring(body(self) or '') .. "\n\n")
    return final_str
end

------------------------------------------------
--- Task Manager
------------------------------------------------

local TaskManager = {}
TaskManager.__index = TaskManager

-- creates new task manager
function TaskManager.new()
    return setmetatable({
        fields = {},
        transients = {},
        tasktypes = {},
        modifiers = {},
        tasks = {}
    }, TaskManager)
end

-- registers a field

-- function TaskManager:field(name)
--     return function(tab)
--         assert(type(tab) == "table", "field: expected a table")
--         assert(tab.validate or tab.derive, "Field definition must include at least a validate or derive function.")
--         self.fields[name] = tab
--     end
-- end

-- registers a transient field which is not stored anywhere
-- a `tasktypes` list scopes which task types the transient applies to;
-- omit it (or leave it nil) to apply the transient to every task type
function TaskManager:transient(name)
    return function(tab)
        assert(type(tab) == "table", "transient: expected a table")
        assert(tab.derive, "Field definition must include at least a derive function.")
        self.transients[name] = tab
    end
end

-- the ordered chain of task type definitions from root ancestor to vextype itself
function TaskManager:typechain(vextypename)
    local vextype = self.tasktypes[vextypename]
    if not vextype then return {} end
    local chain = {vextype}
    while chain[1].parent do
        table.insert(chain, 1, self.tasktypes[chain[1].parent])
    end
    return chain
end

-- whether a transient definition applies to a given task type,
-- considering that task type's parent chain
function TaskManager:appliestransient(vextypename, def)
    if not def.tasktypes then return true end
    local wanted = {}
    for _, name in ipairs(def.tasktypes) do wanted[name] = true end
    for _, vextype in ipairs(self:typechain(vextypename)) do
        if wanted[vextype.name] then return true end
    end
    return false
end

-- register mod
function TaskManager:modifier(name, modfunc)
	assert(type(modfunc) == "function", "Must supply a modifier function")
	self.modifiers[name] = modfunc
end

-- registers task type
function TaskManager:registertask(name, parent, tab)
    assert(name, "Task must have a task name")
    assert(tab.schema, "Cannot register a task type without a valid schema. Ensure your task type is registered with a `schema` field which is a schema.")
    assert(not self.tasktypes[name], "Task with name " .. tostring(name) .. " already exists.")
    assert(not parent or self.tasktypes[parent], "Unknown parent of name " .. tostring(parent))
    self.tasktypes[name] = {
        parent = parent,
        name = name,
        schema = tab.schema,
        fields = tab.fields
    }
    if type(tab.schema.specification) == "table" then 
        for key in pairs(tab.schema.specification) do 
            self.fields[key] = true
        end 
    end 
end

-- setup modifier behaviour 
function TaskManager:applymods(name, modifiers)
	local tasktype = func.map(self.tasktypes[name], function(v) return v end) -- copy 
	for _, modifier in ipairs(modifiers) do
		tasktype = self.modifiers[modifier](tasktype)
	end
	return tasktype
end

-- register task with sugar 
function TaskManager:task(name)
	return setmetatable({
		extends = function(this, parent)
			return function(task)
				return self:registertask(name, parent, task)
			end
		end,
		modify = function(this, parent)
			return function(modifiers)
				return self:registertask(name, nil, self:applymods(parent, modifiers))
			end 
		end 
	}, {
		__call = function(_, task)
			return self:registertask(name, nil, task)
		end
	})
end

---------------------------------------------------
-- Tasks and focuses
---------------------------------------------------

-- Get a table of tasks 
function TaskManager:gettasks(focus)
    
end

-- gets single task by id
-- first attempts to get it from the index, but then tries reading it 
function TaskManager:getsingle(vexid)
    assert(vexid, "getsingle() requires an id")
    self.tasks[vexid] = self.tasks[vexid] or self:read(vexid)
    return self.tasks[vexid]
end

-- converts an id list to a focus representation
-- allows composable focuses from id lists
-- function TaskManager:to_focus(tasks)
--     cli:throw('unimplemented')
--     if tasks.vexid then return {tasks} end 
--     return tasks 
-- end

---------------------------------------------------
-- Public API
---------------------------------------------------

-- creates new task
function TaskManager:add(task)
    assert(task and type(task) == "table", "add() requires a table of task properties")
    if not (type(task.description) == "string") then cli:throw("task-creation-failed", "task must have a description to be added") end
    if not (#task.description > 3) then cli:throw("task-creation-failed", "Need more than 3 characters to create a task") end
    
    task.vexid = tagger.generate(task.description, vexdex.index)
    local existing_task = self:getsingle(task.vexid)
    if existing_task then cli:throw('task-already-exists', task.vexid, existing_task.path) end 
    task.vextype = task.vextype or 'task'

    self.tasks[task.vexid] = Task.new(task)
    return task.vexid
end

-- removes task by id or focus
function TaskManager:remove(vexid)
    assert(vexid, "remove() requires an id or focus")
    self.tasks[vexid] = nil
    return vexid
end

-- gets data from a task and returns it as a string for the command line
function TaskManager:get(vexid, fields)
    return Task.new(self:present(vexid)):tostring(fields)
end

-- sets task properties for a given focus
function TaskManager:set(vexid, tab)
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
function TaskManager:show(vexid)
    assert(vexid, "show() requires an vexid")
    return Task.new(self:present(vexid)):show(self:getabspath(vexid))
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

-- rebuild the entire vexdex by iterating through the filesystem
function TaskManager:reindexall()
    for key in pairs(vexdex.index) do
        vexdex:unsafe_remove(key)
    end

    local vexids = func.ifilter(func.imap(lfsext.walk(vexdex.path .. '/' .. config.taskfolder), function(path) 
        local t = self:readfrompath(path)
        return t and t.vexid
    end), function(vexid) return vexid end)

    for _, vexid in ipairs(vexids) do
        self:read(vexid)
        self:resolve(vexid)
        vexdex:unsafe_add(vexid, self.tasks[vexid])
    end
    vexdex:writeindex()
    return self 
end

local function normalise(vextype, task, context)
    vextype.schema.prevalidate(vextype.schema, task, context)
    local ok, res = pcall(vextype.schema.prevalidate, vextype.schema, task, context)
    if not ok then cli:throw('resolution-failed-normalisation', context.vexid, context.path, tostring(res)) end 
    return res
end 

local function validate(vextype, task, context)
    return vextype.schema:validate(task, context) 
end 

local function derive(vextype, task, context)
    local ok, res = pcall(vextype.schema.postvalidate, vextype.schema, task, context)
    if not ok then cli:throw('resolution-failed-derivation', context.vexid, context.path, tostring(res)) end 
    return res
end 

-- adds it to the index
function TaskManager:index(vexid)
    vexdex:add(vexid, self.tasks[vexid])
end

-- removes from the index
function TaskManager:unindex(vexid)
    vexdex:remove(vexid)
end

-- resolve
function TaskManager:resolve(vexid)
    if not vexid then cli:throw('missing-required-field', vexid, 'vexid') end 

    local task = self:getsingle(vexid) or {}
    if not task.vextype then cli:throw('missing-required-field', task.vexid, 'vextype') end 

    local vextype = self.tasktypes[task.vextype]
    if not vextype then cli:throw('unknown-vextype', vextype, func.keys(self.tasktypes)) end 

    local context = {
        vexid = vexid,
        taskmanager = self, 
        task = task, 
    }

    local parents = {vextype} 
    while parents[1].parent do
        local parent = self.tasktypes[parents[#parents].parent]
        table.insert(parents, 1, parent)
    end 

    for _, parent in ipairs(parents) do 
        if not normalise(parent, task, context) then cli:throw('resolution-failed-normalisation', vexid) end 
        local isvalid, err = validate(parent, task, context)
        if not isvalid then cli:throw('resolution-failed-validation', vexid, err) end 
        if not derive(parent, task, context) then cli:throw('resolution-failed-derivation', vexid) end 
    end 

    self.tasks[vexid] = task
    self:index(vexid)
end

---------------------------------------------------
-- File I/O
---------------------------------------------------

-- format a task 
function TaskManager:format(vexid)
    local task = self:getsingle(vexid)
    local vextype = self.tasktypes[task.vextype]

    local parents = {vextype}
    while parents[1].parent do
        table.insert(parents, 1, self.tasktypes[parents[1].parent])
    end

    local formatted = {}
    for k, v in pairs(task) do formatted[k] = v end

    for _, parent in ipairs(parents) do
        for subschema, instance, schemakey, instancekey in parent.schema:iterate(task) do
            if instancekey and instance ~= nil then
                local iso_owner = subschema:findiso('format', instance)
                if iso_owner and iso_owner:validate(instance) then
                    formatted[instancekey] = subschema:apply('format', instance)
                end
            end
        end
    end

    return formatted
end

-- format a task for display/API output, additionally computing every
-- applicable transient field on top. Transients are computed fresh on
-- every call and never written back onto the task -- format() (used by
-- write()) is untouched by this, which is what keeps transients out of
-- vexdex and off disk.
function TaskManager:present(vexid)
    local presented = self:format(vexid)
    local task = self:getsingle(vexid)
    local context = {vexid = vexid, taskmanager = self, task = task}
    for name, def in pairs(self.transients) do
        if self:appliestransient(task.vextype, def) then
            presented[name] = def.derive(task, context)
        end
    end
    return presented
end

-- get the path that a task should live at
function TaskManager:getabspath(vexid)
    return vexdex.path .. '/' .. config.taskfolder .. '/' .. self:getrelpath(vexid)
end

function TaskManager:getrelpath(vexid)
    return taskpath.path(self, config, vexid)
end

-- reads a file from disk and adds it to memory
function TaskManager:read(vexid)
    return self:readfrompath(self:getabspath(vexid))
end

-- reads a file from disk and adds it to memory by path
function TaskManager:readfrompath(path)
    local ok, task = pcall(taskformat.read, path)
    if ok and task then 
        self.tasks[task.vexid] = Task.new(task)
        self:index(task.vexid)
        return task
    else 
        return nil 
    end
end

-- writes a file from disk
function TaskManager:write(vexid)
    local task = self:format(vexid)
    vexdex:atomic(self:getabspath(vexid), function(path)
        taskformat.write(path, sortdata(frontmatter(task)), body(task))
    end)
    self:index(vexid)
    return vexid
end

-- deletes a file from disk
function TaskManager:delete(vexid)
    os.remove(self:getabspath(vexid))
    self:unindex(vexid)
    return vexid
end

---------------------------------------------------
-- Create single instance and init 
---------------------------------------------------

return TaskManager.new()
