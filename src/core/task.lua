
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
local hash = require 'lib.hash'

local taskmanager

local function taskroot()
    return vexdex.path .. '/' .. config.taskfolder
end

------------------------------------------------
--- Tasks
------------------------------------------------

local Task = {}

function Task:__index(key)
    if Task[key] then return Task[key] end
    if key == 'vexbody' then
        local held = taskmanager:getsingle(rawget(self, 'vexid'))
        return held and rawget(held, 'vexbody')
    end
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

-- the vexids a task links to, held in any field its type's schemas validate as a vexlink
function TaskManager:forwardlinks(task)
    local linked, seen = {}, {}
    local tasktype = self.tasktypes[task.vextype]
    while tasktype do
        for _, vexid in ipairs(tasktype.schema:collect('vexlink', task)) do
            if not seen[vexid] then
                seen[vexid] = true
                table.insert(linked, vexid)
            end
        end
        tasktype = self.tasktypes[tasktype.parent]
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
        local linkers = focus.focus(vexid):step('backlinks'):get()
        for _, linker in ipairs(linkers) do
            for field, value in pairs(linker) do
                if value == vexid then
                    linker[field] = nil
                elseif type(value) == "table" then
                    linker[field] = func.ifilter(value, function(link) return link ~= vexid end)
                end
            end
            self.tasks[linker.vexid] = linker
        end
        self:resolveall(func.imap(linkers, function(linker) return linker.vexid end))
    end
    self.tasks[vexid] = nil
    event:trigger('post-task-remove', vexid)
    return vexid
end

-- gets data from a task and returns it as a string for the command line
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

    self.mtimes = lfsext.mtimes(taskroot())
    local vexids, paths = {}, {}
    for _, path in ipairs(func.sortedkeys(self.mtimes)) do
        local task = self:readfrompath(path)
        if task then
            if paths[task.vexid] then cli:throw('duplicate-vexid', task.vexid, paths[task.vexid], path) end
            paths[task.vexid] = path
            table.insert(vexids, task.vexid)
        end
    end

    for _, vexid in ipairs(vexids) do self:index(vexid) end
    self:resolveall(vexids)
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

-- adds it to the index, which is saved when the verb finishes
function TaskManager:index(vexid)
    vexdex:unsafe_add(vexid, self.tasks[vexid])
end

-- resolves one task and returns the vexids of the tasks linked to or from it, and of those it stopped linking to
function TaskManager:resolvesingle(vexid)
    if not vexid then cli:throw('missing-required-field', vexid, 'vexid') end 
    event:trigger('pre-task-resolve', vexid)

    local previous = vexdex:get(vexid) or {}
    local task = self:getsingle(vexid) or {}
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

    local unlinked = func.ifilter(previous.forwardlinks or {}, function(target)
        return not func.any(context.links, function(link) return link == target end)
    end)
    self.tasks[vexid] = task
    local fingerprint = self:fingerprint(vexid)
    local stamped = (vexdex.files[vexid] or {}).fingerprint
    if stamped and stamped ~= fingerprint then
        task.modified = os.time()
        fingerprint = self:fingerprint(vexid)
    end
    vexdex:unsafe_stamp(vexid, {fingerprint = fingerprint})
    vexdex:unsafe_link(vexid, context.links)
    vexdex:unsafe_add(vexid, task)

    event:trigger('post-task-resolve', vexid, task)
    return func.imerge(unlinked, func.imerge(task.forwardlinks, task.backlinks))
end

-- resolves the given tasks and everything linked to them, each once, writes each and moves every file to where it belongs
function TaskManager:resolveall(vexids)
    local resolved, requested, pending = {}, {}, {}
    for _, vexid in ipairs(vexids) do
        requested[vexid] = true
        table.insert(pending, vexid)
    end
    for _, vexid in ipairs(pending) do
        if not resolved[vexid] and (requested[vexid] or vexdex:get(vexid)) then
            resolved[vexid] = true
            for _, linked in ipairs(self:resolvesingle(vexid)) do table.insert(pending, linked) end
        end
    end
    for vexid in pairs(resolved) do
        self:write(vexid)
        self:move(vexid)
    end
end

function TaskManager:resolve(vexid)
    self:resolveall({vexid})
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

local function contents(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

-- the text of a task's file, leaving out the given fields
function TaskManager:render(vexid, exclude)
    local task = self:format(vexid)
    local fields = frontmatter(task)
    for _, field in ipairs(exclude or {}) do fields[field] = nil end
    return taskformat.render(sortdata(fields), body(task))
end

-- a hash of what a task holds, leaving out the fields config.fingerprint.exclude names
function TaskManager:fingerprint(vexid)
    return hash.fnv1a(self:render(vexid, (config.fingerprint or {}).exclude))
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

-- reads a file from disk and adds it to memory by path; a file that cannot be read or holds no vexid gives nil
function TaskManager:readfrompath(path)
    event:trigger('pre-task-read', path)
    local ok, task = pcall(taskformat.read, path)
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
    local task = self:format(vexid)
    local path = self:getcurrentpath(vexid)
    if self:render(vexid) ~= contents(path) then
        lfs.mkdir(dirname(path))
        vexdex:atomic(path, function(path)
            taskformat.write(path, sortdata(frontmatter(task)), body(task))
        end)
        self.mtimes = self.mtimes or {}
        self.mtimes[path] = lfsext.mtime(path)
    end
    if self.mtimes and self.mtimes[path] then vexdex:unsafe_stamp(vexid, {mtime = self.mtimes[path]}) end
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

-- drops a task from the index, leaving its file alone, and resolves the tasks it was linked to or from
function TaskManager:forget(vexid)
    event:trigger('pre-task-forget', vexid)
    local linked = focus.focus(vexid):step('forwardlinks', 'backlinks'):get()
    vexdex:unsafe_remove(vexid)
    self.tasks[vexid] = nil
    self:resolveall(func.imap(linked, function(task) return task.vexid end))
    event:trigger('post-task-forget', vexid)
    return vexid
end

-- deletes a file from disk
function TaskManager:delete(vexid)
    event:trigger('pre-task-delete', vexid)
    local path = self:getcurrentpath(vexid)
    os.remove(path)
    tidy(path)
    self:forget(vexid)
    event:trigger('post-task-delete', vexid, path)
    return vexid
end

---------------------------------------------------
-- Changes on disk
---------------------------------------------------

-- the tasks whose files changed since vex last saw them: edited, new, moved, unreadable or gone
function TaskManager:updated()
    self.mtimes = lfsext.mtimes(taskroot())
    local located, held = {}, {}
    for vexid in pairs(vexdex.index) do
        local path = self:getcurrentpath(vexid)
        located[path] = vexid
        if self.mtimes[path] then held[vexid] = path end
    end
    local updated, seen = {}, {}
    for _, path in ipairs(func.sortedkeys(self.mtimes)) do
        local vexid = located[path]
        if not (vexid and (vexdex.files[vexid] or {}).mtime == self.mtimes[path]) then
            local task = self:readfrompath(path)
            if task then
                local other = seen[task.vexid] or held[task.vexid]
                if other and other ~= path then cli:throw('duplicate-vexid', task.vexid, other, path) end
                seen[task.vexid] = path
                table.insert(updated, vexdex:get(task.vexid) or self.tasks[task.vexid])
            elseif vexid then
                table.insert(updated, vexdex:get(vexid))
            end
        end
    end
    for _, vexid in ipairs(func.sortedkeys(vexdex.index)) do
        if not seen[vexid] and not held[vexid] then table.insert(updated, vexdex:get(vexid)) end
    end
    return updated
end

-- resolves the given tasks (every task when none are given) whose files changed since vex last saw them, and forgets those whose files are gone or unreadable
function TaskManager:refresh(vexids)
    event:trigger('pre-task-refresh', vexids)
    local wanted
    if vexids then
        wanted = {}
        for _, vexid in ipairs(vexids) do wanted[vexid] = true end
    end
    local changed = {}
    for _, updated in ipairs(self:updated()) do
        if not wanted or wanted[updated.vexid] then
            if self:readfrompath(self:getcurrentpath(updated.vexid)) then
                if not vexdex:get(updated.vexid) then self:index(updated.vexid) end
                table.insert(changed, updated.vexid)
            else
                self:forget(updated.vexid)
            end
        end
    end
    self:resolveall(changed)
    event:trigger('post-task-refresh', vexids, changed)
    return changed
end

---------------------------------------------------
-- Create single instance and init 
---------------------------------------------------

focus.focus('all'):each_task(Task.new)
taskmanager = TaskManager.new()
return taskmanager
