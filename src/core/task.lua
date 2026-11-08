
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
local naturaltime = require 'lib.naturaltime'
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
function Task:tostring(fields, colsep)
    return table.concat(func.imap(fields, function(field)
        local value = self[field]
        if value == nil then return "" end
        return type(value) == "table" and table.concat(value, ",") or tostring(value)
    end), colsep or "\t")
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
        tasks = {},
        unwritten = {},
        deleted = {}
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
        schema = parent and self.tasktypes[parent].schema:merge(tab.schema) or tab.schema,
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
    return tasktype and select(2, tasktype.schema:get({}, {field}))
end

-- whether a type's field holds a date or datetime
function TaskManager:isdatefield(vextype, field)
    local fieldschema = self:schemaof(vextype, field)
    return fieldschema ~= nil and #fieldschema:collect('datetime', 0) + #fieldschema:collect('date', 0) > 0
end

function TaskManager:transientof(vextype, name)
    local tasktype = self.tasktypes[vextype]
    local definitions = self.transients[name] or {}
    while tasktype do
        if definitions[tasktype.name] then return definitions[tasktype.name] end
        tasktype = self.tasktypes[tasktype.parent]
    end
end

-- the vexids a task links to, held in any field its type's schema validates as a vexlink
function TaskManager:forwardlinks(task)
    local linked, seen = {}, {}
    for _, vexid in ipairs(self.tasktypes[task.vextype].schema:collect('vexlink', task)) do
        if not seen[vexid] then
            seen[vexid] = true
            table.insert(linked, vexid)
        end
    end
    table.sort(linked)
    return linked
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
    
    local taken = setmetatable({}, {__index = function(_, vexid) return vexdex.index[vexid] or self.tasks[vexid] end})
    task.vexid = tagger.generate(task.description, taken)
    local existing_task = self:getsingle(task.vexid)
    if existing_task then cli:throw('task-already-exists', task.vexid, existing_task.path) end 
    task.vextype = task.vextype or (config.default and config.default.tasktype) or 'task'

    self.tasks[task.vexid] = Task.new(task)
    event:trigger('post-task-add', task.vexid, self.tasks[task.vexid])
    return task.vexid
end

-- adds the next task of a recurring task, its `over` date moved on by its `recur`, among its parent's children
function TaskManager:recur(vexid)
    local finished = self:getsingle(vexid)
    local nexttask = func.map(finished, function(value)
        return type(value) == "table" and func.map(value, function(v) return v end) or value
    end)
    nexttask.vexid, nexttask.created, nexttask.modified, nexttask.status = nil, nil, nil, nil
    local over = finished.over or 'due'
    nexttask[over] = naturaltime.parse(finished.recur, finished[over] or os.time())
    local successor = self:add(nexttask)
    self:resolve(successor)
    local parent = finished.parent
    if parent and self:getsingle(parent).children then
        self:set(parent, {children = successor}, {children = 'insert'})
        self:resolve(parent)
    end
    return successor
end

-- removes task by id or focus
function TaskManager:remove(vexid)
    assert(vexid, "remove() requires an id or focus")
    event:trigger('pre-task-remove', vexid)
    if vexdex:get(vexid) then
        local linkers = func.imap(focus.focus(vexid):step('backlinks'):get(), function(linker) return linker.vexid end)
        for _, linker in ipairs(linkers) do
            local task = self:getsingle(linker)
            for field, value in pairs(task) do
                if value == vexid then
                    task[field] = nil
                elseif type(value) == "table" then
                    task[field] = func.ifilter(value, function(link) return link ~= vexid end)
                end
            end
        end
        self:resolveall(linkers)
    end
    self.tasks[vexid] = nil
    event:trigger('post-task-remove', vexid)
    return vexid
end

-- gets data from a task as last committed to the index and returns it as a string for the command line
function TaskManager:get(vexid, fields, colsep)
    event:trigger('pre-task-get', vexid, fields)
    local result = self:format(vexid):tostring(fields, colsep)
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

-- sets task properties for a given focus; modifiers[field] = 'insert' or 'remove' edits a list by value instead, and 'clear' unsets the field
function TaskManager:set(vexid, tab, modifiers)
    assert(tab and type(tab) == "table", "set() requires a table")
    event:trigger('pre-task-set', vexid, tab, modifiers)
    local task = {}
    for k, v in pairs(self:getsingle(vexid)) do task[k] = v end
    for k,v in pairs(tab) do 
        if k == "vexid" then cli:throw('immutable-vexid', vexid) end
        local modifier = modifiers and modifiers[k]
        if modifier == 'clear' then cli:throw('clear-with-value', k) end
        if modifier then
            if not listmodifiers[modifier] then cli:throw('unknown-modifier', modifier) end
            task[k] = listmodifiers[modifier](aslist(task[k]), aslist(v))
        else
            task[k] = v
        end
    end
    for k, modifier in pairs(modifiers or {}) do
        if modifier == 'clear' then
            if k == "vexid" then cli:throw('immutable-vexid', vexid) end
            task[k] = nil
        end
    end
    self.tasks[vexid] = Task.new(task)
    event:trigger('post-task-set', vexid, self.tasks[vexid])
    return self.tasks[vexid] 
end

-- shows a task's file as it is on disk
function TaskManager:show(vexid)
    assert(vexid, "show() requires an vexid")
    event:trigger('pre-task-show', vexid)
    local path = self:getcurrentpath(vexid)
    if lfs.attributes(path, 'mode') ~= 'file' then path = self:find(vexid) or path end
    local text = lfsext.readfile(path)
    if not text then cli:throw('file', path) end
    local result = pretty.string('# ' .. string.upper(vexid) .. '\n', 'cyan', 'underline', 'bold', {filelink = path}) .. taskformat.format(text)
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

-- takes in the task files that changed on disk since vex last saw them, or with force every task file, and resolves them
function TaskManager:reindexall(force)
    event:trigger('pre-task-reindexall', force)
    if force then
        for key in pairs(vexdex.index) do vexdex:unsafe_remove(key, vexdex:get(key).forwardlinks) end
    end
    local recorded = func.map(vexdex.paths, function(path) return path end)
    local vexids, unknown = vexdex:updated()
    local found = {}
    for _, path in ipairs(unknown) do
        local task = self:readfrompath(path)
        if task then
            local other = found[task.vexid] or (recorded[task.vexid] and vexdex:taskroot() .. '/' .. recorded[task.vexid])
            if other and lfs.attributes(other, 'mode') == 'file' then cli:throw('duplicate-vexid', task.vexid, other, path) end
            found[task.vexid] = path
            if not vexdex:get(task.vexid) then self:index(task.vexid) end
            table.insert(vexids, task.vexid)
        end
    end
    self:resolveall(vexids)
    event:trigger('post-task-reindexall', force)
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

-- adds it to the index, which is saved when the verb finishes
function TaskManager:index(vexid)
    vexdex:unsafe_add(vexid, self.tasks[vexid])
end

-- resolves one task and returns the vexids of the tasks linked to or from it, and of those it stopped linking to, and whether it changed
function TaskManager:resolvesingle(vexid)
    if not vexid then cli:throw('missing-required-field', vexid, 'vexid') end 
    event:trigger('pre-task-resolve', vexid)

    local previous = vexdex:get(vexid) or {}
    local previouslinks = previous.forwardlinks or {}
    local task = self:getsingle(vexid)
    if not task and vexdex:get(vexid) then
        local linked = func.imerge(previouslinks, previous.backlinks)
        vexdex:unsafe_remove(vexid, previouslinks)
        event:trigger('post-task-resolve', vexid, nil)
        return linked, true
    end
    task = task or {}
    if not task.vextype then cli:throw('missing-required-field', task.vexid, 'vextype') end 

    local vextype = self.tasktypes[task.vextype]
    if not vextype then cli:throw('unknown-vextype', task.vextype, func.keys(self.tasktypes)) end 

    local context = {
        vexid = vexid,
        taskmanager = self, 
        task = task, 
        previous = previous,
        links = {},
    }

    if not normalise(vextype, task, context) then cli:throw('resolution-failed-normalisation', vexid) end 
    local isvalid, err = validate(vextype, task, context)
    if not isvalid then cli:throw('resolution-failed-validation', vexid, err, taskfile(context)) end 
    if not derive(vextype, task, context) then cli:throw('resolution-failed-derivation', vexid) end 

    local unlinked = func.ifilter(previouslinks, function(target)
        return not func.any(context.links, function(link) return link == target end)
    end)
    local changed, edited = vexdex:changed(vexid, task)
    if edited then task.modified = os.time() end
    self.tasks[vexid] = task
    vexdex:unsafe_link(vexid, context.links, previouslinks)
    vexdex:unsafe_add(vexid, task)

    event:trigger('post-task-resolve', vexid, task, previous)
    return func.imerge(unlinked, func.imerge(task.forwardlinks, task.backlinks)), changed
end

-- resolves the given tasks and the tasks linked to each one that changed, each once, in memory, keeping them for writeall; a task whose file is gone or unreadable leaves the index
function TaskManager:resolveall(vexids)
    local resolved, requested, pending, changed = {}, {}, {}, {}
    for _, vexid in ipairs(vexids) do
        requested[vexid] = true
        table.insert(pending, vexid)
    end
    for _, vexid in ipairs(pending) do
        if not resolved[vexid] and (requested[vexid] or vexdex:get(vexid)) then
            resolved[vexid] = true
            local linked
            linked, changed[vexid] = self:resolvesingle(vexid)
            if changed[vexid] or self:getabspath(vexid) ~= self:getcurrentpath(vexid) then
                for _, link in ipairs(linked) do table.insert(pending, link) end
            end
        end
    end
    for vexid in pairs(resolved) do
        self.unwritten[vexid] = self.unwritten[vexid] or changed[vexid]
    end
end

function TaskManager:resolve(vexid)
    self:resolveall({vexid})
end

---------------------------------------------------
-- File I/O
---------------------------------------------------

local function format(tasktypes, task)
    local formatted = tasktypes[task.vextype].schema:apply('format', task)
    return setmetatable(formatted, {__index = task})
end

-- formats a task as last committed to the index
function TaskManager:format(vexid)
    return format(self.tasktypes, vexdex:get(vexid))
end

function TaskManager:unformat(task)
    local vextype = self.tasktypes[task.vextype]
    if not vextype then return task end
    return vextype.schema:unapply('format', task)
end

local function relative(path)
    local root = vexdex:taskroot() .. '/'
    if path:sub(1, #root) == root then return path:sub(#root + 1) end
end

local function dirname(path)
    return path:match("^(.*)/")
end

local function tidy(path)
    local dir = dirname(path)
    while #dir > #vexdex:taskroot() and os.remove(dir) do
        dir = dirname(dir)
    end
end

-- get the path that a task should live at
function TaskManager:getabspath(vexid)
    return vexdex:taskroot() .. '/' .. self:getrelpath(vexid)
end

-- get the path that a task's file currently lives at
function TaskManager:getcurrentpath(vexid)
    local relpath = vexdex.paths[vexid]
    if not relpath then return self:getabspath(vexid) end
    return vexdex:taskroot() .. '/' .. relpath
end

-- finds a task's file anywhere in the taskfolder by its filename
function TaskManager:find(vexid)
    local filename = self:getrelpath(vexid):match("[^/]*$")
    return func.ifilter(lfsext.walk(vexdex:taskroot()), function(path) return path:match("[^/]*$") == filename end)[1]
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

-- reads a file from disk and adds it to memory by path; a file that cannot be read or holds no vexid gives nil
function TaskManager:readfrompath(path)
    event:trigger('pre-task-read', path)
    local ok, task = pcall(taskformat.parse, path and lfsext.readfile(path) or "")
    if ok and task and task.vexid then 
        task = self:unformat(task)
        self.tasks[task.vexid] = Task.new(task)
        if relative(path) then vexdex:unsafe_locate(task.vexid, relative(path)) end
        event:trigger('post-task-read', path, self.tasks[task.vexid])
        return task
    else 
        event:trigger('post-task-read', path, nil)
    end
end

-- writes a file from disk
function TaskManager:write(vexid)
    event:trigger('pre-task-write', vexid)
    local task = format(self.tasktypes, self:getsingle(vexid))
    local path = self:getcurrentpath(vexid)
    local text = taskformat.render(sortdata(frontmatter(task)), body(task))
    lfsext.mkdirs(dirname(path))
    vexdex:atomic(path, function(tmp) lfsext.writefile(tmp, text) end)
    vexdex:unsafe_stamp(vexid, path)
    vexdex:unsafe_locate(vexid, relative(path))
    self:index(vexid)
    event:trigger('post-task-write', vexid, path)
    return vexid
end

-- moves a task's file to the path it should live at
function TaskManager:move(vexid)
    event:trigger('pre-task-move', vexid)
    local relpath = self:getrelpath(vexid)
    local from, to = self:getcurrentpath(vexid), vexdex:taskroot() .. '/' .. relpath
    if from ~= to and lfs.attributes(from, "mode") ~= "file" then from = self:find(vexid) end
    if from and from ~= to then
        lfsext.mkdirs(dirname(to))
        local ok, err = os.rename(from, to)
        if not ok then cli:throw('move-failed', vexid, from, to, err) end
        tidy(from)
    end
    vexdex:unsafe_locate(vexid, relpath)
    event:trigger('post-task-move', vexid, from, to)
    return vexid
end

-- deletes a file from disk
function TaskManager:delete(vexid)
    event:trigger('pre-task-delete', vexid)
    local linked = focus.focus(vexid):step('forwardlinks', 'backlinks'):get()
    local path = self:getcurrentpath(vexid)
    table.insert(self.deleted, path)
    vexdex:unsafe_remove(vexid, vexdex:get(vexid).forwardlinks)
    self:resolveall(func.imap(linked, function(task) return task.vexid end))
    event:trigger('post-task-delete', vexid, path)
    return vexid
end

-- commits: writes the resolved tasks that changed, moves every resolved file to where it belongs, removes the deleted files, then saves the index
function TaskManager:writeall()
    for vexid, changed in pairs(self.unwritten) do
        if vexdex:get(vexid) then
            if changed then self:write(vexid) else vexdex:unsafe_stamp(vexid, self:getcurrentpath(vexid)) end
            self:move(vexid)
        end
    end
    for _, path in ipairs(self.deleted) do
        os.remove(path)
        tidy(path)
    end
    self.deleted, self.unwritten = {}, {}
    vexdex:writeindex()
end

---------------------------------------------------
-- Create single instance and init 
---------------------------------------------------

focus.focus('all'):each_task(Task.new)
taskmanager = TaskManager.new()
return taskmanager
