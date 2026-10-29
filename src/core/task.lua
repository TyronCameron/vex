
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
local focus = require 'core.focus'
local config = require 'core.config'
local event = require 'lib.event'

local taskmanager

------------------------------------------------
--- Tasks
------------------------------------------------

local Task = {}

function Task:__index(key)
    if Task[key] then return Task[key] end
    local transient = taskmanager:transientof(rawget(self, 'vextype'), key)
    return transient and transient.definition(self)
end

-- construction
function Task.new(task)
    assert(type(task) == "table", "A task must be a table of information")
    assert(task.vexid, "A task must have a vexid")
    return setmetatable(task, Task)
end

-- gets data from a task and returns it as a string for the command line
function Task:tostring(fields)
    return table.concat(func.imap(fields, function(field)
        local value = self[field]
        if value == nil then return "" end
        return type(value) == "table" and table.concat(value, ",") or tostring(value)
    end), "\t")
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
function TaskManager:transient(name)
    return function(tab)
        assert(type(tab) == "table", "transient: expected a table")
        assert(type(tab.definition) == "function", "Transient definition must include a definition function.")
        assert(self.tasktypes[tab.vextype], "Unknown vextype of name " .. tostring(tab.vextype) .. " for transient " .. tostring(name))
        self.transients[name] = self.transients[name] or {}
        self.transients[name][tab.vextype] = tab
    end
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

function TaskManager:schemaof(vextype, field)
    local tasktype = self.tasktypes[vextype]
    while tasktype do
        local _, fieldschema = tasktype.schema:get({}, {field})
        if fieldschema then return fieldschema end
        tasktype = self.tasktypes[tasktype.parent]
    end
end

function TaskManager:transientof(vextype, name)
    local tasktype = self.tasktypes[vextype]
    local definitions = self.transients[name] or {}
    while tasktype do
        if definitions[tasktype.name] then return definitions[tasktype.name] end
        tasktype = self.tasktypes[tasktype.parent]
    end
end

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
    event:trigger('pre-task-add', task)
    if not (type(task.description) == "string") then cli:throw("task-creation-failed", "task must have a description to be added") end
    if not (#task.description > 3) then cli:throw("task-creation-failed", "Need more than 3 characters to create a task") end
    
    task.vexid = tagger.generate(task.description, vexdex.index)
    local existing_task = self:getsingle(task.vexid)
    if existing_task then cli:throw('task-already-exists', task.vexid, existing_task.path) end 
    task.vextype = task.vextype or (config.default and config.default.tasktype) or 'task'

    self.tasks[task.vexid] = Task.new(task)
    event:trigger('post-task-add', task.vexid, self.tasks[task.vexid])
    return task.vexid
end

-- removes task by id or focus
function TaskManager:remove(vexid)
    assert(vexid, "remove() requires an id or focus")
    event:trigger('pre-task-remove', vexid)
    if vexdex:get(vexid) then
        focus.focus(vexid):backlinks():each_task(function(linker)
            for field, value in pairs(linker) do
                if value == vexid then
                    linker[field] = nil
                elseif type(value) == "table" then
                    linker[field] = func.ifilter(value, function(link) return link ~= vexid end)
                end
            end
            self.tasks[linker.vexid] = linker
            self:resolve(linker.vexid)
            self:write(linker.vexid)
        end)
    end
    self.tasks[vexid] = nil
    event:trigger('post-task-remove', vexid)
    return vexid
end

-- gets data from a task and returns it as a string for the command line
function TaskManager:get(vexid, fields)
    event:trigger('pre-task-get', vexid, fields)
    local result = self:format(vexid):tostring(fields)
    event:trigger('post-task-get', vexid, fields, result)
    return result
end

local function aslist(value)
    if value == nil then return {} end
    return type(value) == "table" and value or {value}
end

local listmodifiers = {
    insert = function(current, values)
        local result = func.imap(current, function(v) return v end)
        for _, value in ipairs(values) do
            if not func.any(result, function(v) return v == value end) then table.insert(result, value) end
        end
        return result
    end,
    remove = function(current, values)
        return func.ifilter(current, function(v)
            return not func.any(values, function(value) return value == v end)
        end)
    end,
}

-- sets task properties for a given focus; modifiers[field] = 'insert' or 'remove' edits a list by value instead
function TaskManager:set(vexid, tab, modifiers)
    assert(tab and type(tab) == "table", "set() requires a table")
    event:trigger('pre-task-set', vexid, tab, modifiers)
    local task = {}
    for k, v in pairs(self:getsingle(vexid)) do task[k] = v end
    for k,v in pairs(tab) do 
        if k == "vexid" then cli:throw('immutable-vexid', vexid) end
        local modifier = modifiers and modifiers[k]
        if modifier then
            if not listmodifiers[modifier] then cli:throw('unknown-modifier', modifier) end
            task[k] = listmodifiers[modifier](aslist(task[k]), aslist(v))
        else
            task[k] = v
        end
    end
    task.modified = os.time()
    self.tasks[vexid] = Task.new(task)
    event:trigger('post-task-set', vexid, self.tasks[vexid])
    return self.tasks[vexid] 
end

-- shows task, basically cat 'filename'
function TaskManager:show(vexid)
    assert(vexid, "show() requires an vexid")
    event:trigger('pre-task-show', vexid)
    local result = self:format(vexid):show(self:getcurrentpath(vexid))
    event:trigger('post-task-show', vexid, result)
    return result
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
    event:trigger('pre-task-reindexall')
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
    event:trigger('post-task-reindexall')
    return self 
end

local function taskfile(context)
    local path = context.taskmanager:getcurrentpath(context.vexid)
    return lfs.attributes(path, 'mode') == 'file' and path or nil
end

local function normalise(vextype, task, context)
    local ok, res = pcall(vextype.schema.prevalidate, vextype.schema, task, context)
    if not ok then cli:throw('resolution-failed-normalisation', context.vexid, res, taskfile(context)) end 
    return res
end 

local function validate(vextype, task, context)
    return vextype.schema:validate(task, context) 
end 

local function derive(vextype, task, context)
    local ok, res = pcall(vextype.schema.postvalidate, vextype.schema, task, context)
    if not ok then cli:throw('resolution-failed-derivation', context.vexid, res, taskfile(context)) end 
    return res
end 

-- adds it to the index
function TaskManager:index(vexid)
    vexdex:add(vexid, self.tasks[vexid])
end

-- resolve
function TaskManager:resolve(vexid)
    if not vexid then cli:throw('missing-required-field', vexid, 'vexid') end 
    event:trigger('pre-task-resolve', vexid)

    local task = self:getsingle(vexid) or {}
    if not task.vextype then cli:throw('missing-required-field', task.vexid, 'vextype') end 

    local vextype = self.tasktypes[task.vextype]
    if not vextype then cli:throw('unknown-vextype', task.vextype, func.keys(self.tasktypes)) end 

    local context = {
        vexid = vexid,
        taskmanager = self, 
        task = task, 
        previous = vexdex:get(vexid) or {},
        links = {},
    }

    local parents = {vextype} 
    while parents[1].parent do
        table.insert(parents, 1, self.tasktypes[parents[1].parent])
    end 

    for _, parent in ipairs(parents) do 
        if not normalise(parent, task, context) then cli:throw('resolution-failed-normalisation', vexid) end 
        local isvalid, err = validate(parent, task, context)
        if not isvalid then cli:throw('resolution-failed-validation', vexid, err, taskfile(context)) end 
        if not derive(parent, task, context) then cli:throw('resolution-failed-derivation', vexid) end 
    end 

    local unlinked = vexdex:get(vexid) and focus.focus(vexid):forwardlinks():get() or {}
    self.tasks[vexid] = task
    vexdex:unsafe_link(vexid, context.links)
    vexdex:unsafe_add(vexid, task)

    local arranged = {}
    self:arrange(vexid, arranged)
    for _, linked in ipairs(unlinked) do
        self:arrange(linked.vexid, arranged)
    end
    vexdex:writeindex()
    event:trigger('post-task-resolve', vexid, task)
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

    local formatted = task
    for _, parent in ipairs(parents) do
        formatted = parent.schema:apply('format', formatted)
    end
    return setmetatable(formatted, {__index = task})
end

function TaskManager:unformat(task)
    local vextype = self.tasktypes[task.vextype]
    if not vextype then return task end

    local parents = {vextype}
    while parents[1].parent do
        table.insert(parents, 1, self.tasktypes[parents[1].parent])
    end

    local unformatted = task
    for _, parent in ipairs(parents) do
        unformatted = parent.schema:unapply('format', unformatted)
    end
    return unformatted
end

local function taskroot()
    return vexdex.path .. '/' .. config.taskfolder
end

local function relative(path)
    local root = taskroot() .. '/'
    if path:sub(1, #root) == root then return path:sub(#root + 1) end
end

local function dirname(path)
    return path:match("^(.*)/")
end

local function tidy(path)
    local dir = dirname(path)
    while #dir > #taskroot() and os.remove(dir) do
        dir = dirname(dir)
    end
end

-- get the path that a task should live at
function TaskManager:getabspath(vexid)
    return taskroot() .. '/' .. self:getrelpath(vexid)
end

-- get the path that a task's file currently lives at
function TaskManager:getcurrentpath(vexid)
    local relpath = vexdex.paths[vexid]
    if not relpath then return self:getabspath(vexid) end
    return taskroot() .. '/' .. relpath
end

-- finds a task's file anywhere in the taskfolder by its filename
function TaskManager:find(vexid)
    local filename = self:getrelpath(vexid):match("[^/]*$")
    return func.ifilter(lfsext.walk(taskroot()), function(path) return path:match("[^/]*$") == filename end)[1]
end

function TaskManager:getrelpath(vexid)
    return taskpath.path(self, config, vexid)
end

-- reads a file from disk and adds it to memory
function TaskManager:read(vexid)
    local task = self:readfrompath(self:getcurrentpath(vexid))
    if not task and vexdex:get(vexid) then task = self:readfrompath(self:find(vexid)) end
    return task
end

-- reads a file from disk and adds it to memory by path
function TaskManager:readfrompath(path)
    event:trigger('pre-task-read', path)
    local ok, task = pcall(taskformat.read, path)
    if ok and task then 
        task = self:unformat(task)
        self.tasks[task.vexid] = Task.new(task)
        if relative(path) then vexdex:unsafe_locate(task.vexid, relative(path)) end
        self:index(task.vexid)
        event:trigger('post-task-read', path, self.tasks[task.vexid])
        return task
    else 
        event:trigger('post-task-read', path, nil)
        return nil 
    end
end

-- writes a file from disk
function TaskManager:write(vexid)
    event:trigger('pre-task-write', vexid)
    local task = self:format(vexid)
    local path = self:getcurrentpath(vexid)
    lfs.mkdir(dirname(path))
    vexdex:atomic(path, function(path)
        taskformat.write(path, sortdata(frontmatter(task)), body(task))
    end)
    vexdex:unsafe_locate(vexid, relative(path))
    self:index(vexid)
    event:trigger('post-task-write', vexid, path)
    return vexid
end

-- moves a task's file to the path it should live at
function TaskManager:move(vexid)
    event:trigger('pre-task-move', vexid)
    local relpath = self:getrelpath(vexid)
    local from, to = self:getcurrentpath(vexid), taskroot() .. '/' .. relpath
    if from ~= to and lfs.attributes(from, "mode") ~= "file" then from = self:find(vexid) end
    if from and from ~= to then
        lfs.mkdir(dirname(to))
        local ok, err = os.rename(from, to)
        if not ok then cli:throw('move-failed', vexid, from, to, err) end
        tidy(from)
    end
    vexdex:unsafe_locate(vexid, relpath)
    event:trigger('post-task-move', vexid, from, to)
    return vexid
end

-- moves a task's file, and those of every task it links to, to where they should live
function TaskManager:arrange(vexid, arranged)
    if arranged[vexid] then return end
    arranged[vexid] = true
    self:move(vexid)
    focus.focus(vexid):forwardlinks():each(function(linked)
        self:arrange(linked, arranged)
    end)
end

-- deletes a file from disk
function TaskManager:delete(vexid)
    event:trigger('pre-task-delete', vexid)
    local linked = focus.focus(vexid):forwardlinks():get()
    local path = self:getcurrentpath(vexid)
    os.remove(path)
    vexdex:unsafe_remove(vexid)
    tidy(path)
    local arranged = {}
    for _, task in ipairs(linked) do
        self:arrange(task.vexid, arranged)
    end
    vexdex:writeindex()
    event:trigger('post-task-delete', vexid, path)
    return vexid
end

---------------------------------------------------
-- Create single instance and init 
---------------------------------------------------

focus.focus('all'):each_task(Task.new)
taskmanager = TaskManager.new()
return taskmanager
