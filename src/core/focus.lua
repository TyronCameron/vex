
local func = require 'lib.func'
local optic = require 'lib.optic'
local lfs = require 'lib.lfs'
local cli = require 'lib.cli'
local pretty = require 'lib.pretty'
local vexdex = require 'core.vexdex'

local Focus = {
    named = {}
}
Focus.__index = Focus

function Focus.new(name, get, operations)
    return setmetatable({
        name = name, 
        _get = get, 
        operations = operations or {{operation = 'focus', args = {name}}}
    }, Focus)    
end

function Focus.register_focus(name, get)
    Focus.named[name] = Focus.new(name, get)
end

function Focus.getalltasks()
    local tasks = {}
    for _, task in ipairs(func.values(vexdex.index)) do
        table.insert(tasks, task)
    end
    return tasks
end

Focus.register_focus("all", function()
    return Focus.getalltasks() 
end)
Focus.register_focus("none", function() 
    return {} 
end)
Focus.register_focus("updated", function() 
    return func.filter(Focus.getalltasks(), function(task) return task.modified > vexdex.modified end) 
end)

-----------------------------------------
-- Binary Operations 
-----------------------------------------

function Focus:chain(operation, focus, ...)
    if type(focus) == "function" then 
        focus = Focus.new(operation, focus)
    end 
    return Focus.new('chain', function(tasks) 
        return focus:get(self:get(tasks))
    end, func.imerge(self.operations or {}, {{ operation = operation, args = {...} }}))
end

function Focus:intersect(focus)
    return Focus.new('intersect', function(tasks) 
        local dedup = {}
        for _, task in ipairs(self:get(tasks)) do
            if not dedup[task] then 
                dedup[task] = task 
            end 
        end

        local tasklist = {}
        for _, task in ipairs(focus:get(tasks)) do
            if dedup[task] then 
                table.insert(tasklist, task)
            end 
        end
        return tasklist
    end, func.imerge(self.operations or {}, {{ operation = 'intersect', args = {{ name = focus.name, operations = focus.operations }}}}))
end 

function Focus:union(focus)
    return Focus.new('union', function(tasks) 
        local tasklist = {}
        local dedup = {}
        for _, task in ipairs(self:get(tasks)) do
            if not dedup[task] then 
                dedup[task] = true 
                table.insert(tasklist, task)
            end 
        end
        for _, task in ipairs(focus:get(tasks)) do
            if not dedup[task] then 
                dedup[task] = true 
                table.insert(tasklist, task)
            end 
        end
        return tasklist 
    end, func.imerge(self.operations or {}, {{ operation = 'union', args = {{ name = focus.name, operations = focus.operations }}}}))
end 

function Focus:complement()
    return Focus.new('complement', function(tasks) 
        local tasklist = {}
        local hash = {}
        for _, task in ipairs(self:get(tasks)) do 
            hash[task] = true 
        end 
        for _, task in pairs(Focus.getalltasks()) do
            if not hash[task] then table.insert(tasklist, task) end 
        end
        return tasklist 
    end, func.imerge(self.operations or {}, {{ operation = 'complement', args = {}}}))
end 

function Focus:xor(focus)
    return Focus.new('xor', function(tasks) 
        local dedup = {}
        for _, task in ipairs(self:get(tasks)) do
            if not dedup[task] then 
                dedup[task] = task 
            end 
        end
        for _, task in ipairs(focus:get(tasks)) do
            if dedup[task] then 
                dedup[task] = nil
            else 
                dedup[task] = task 
            end 
        end
        return func.values(dedup) 
    end, func.imerge(self.operations or {}, {{ operation = 'xor', args = {{ name = focus.name, operations = focus.operations }}}}))
end 

function Focus:notin(focus)
    return Focus.new('notin', function(tasks) 
        local dedup = {}
        for _, task in ipairs(self:get(tasks)) do
            if not dedup[task] then 
                dedup[task] = task 
            end 
        end
        for _, task in ipairs(focus:get(tasks)) do
            if dedup[task] then 
                dedup[task] = nil
            end 
        end
        return func.values(dedup) 
    end, func.imerge(self.operations or {}, {{ operation = 'notin', args = {{ name = focus.name, operations = focus.operations }}}}))
end 

function Focus:onlyin(focus)
    return Focus.new('onlyin', function(tasks) 
        local dedup = {}
        for _, task in ipairs(focus:get(tasks)) do
            if not dedup[task] then 
                dedup[task] = task 
            end 
        end
        for _, task in ipairs(self:get(tasks)) do
            if dedup[task] then 
                dedup[task] = nil
            end 
        end
        return func.values(dedup) 
    end)
end 

-----------------------------------------
-- Named Focus.named
-----------------------------------------

-- Examples:
-- `prev` which saves the previous focus used. For conciseness, this is the default focus. If no `prev` is available, it uses `none` instead. This applies in all cases except for `focus` itself. 
-- `all`
-- `none`
-- `tag` for any task tag 
-- `path` for any task path (if there is a slash)
-- `updated` for only tasks which have updated against the index. 
-- comma separation of the above is allowed so as to union them

local namedfocus = {}

function namedfocus.from_comma_sep(focusname)
    local focuses = {}
    for name in focusname:gmatch("([^,]+)") do
        table.insert(focuses, namedfocus.get_named_focus(name:match("^%s*(.-)%s*$")))
    end
    local result = table.remove(focuses, 1)
    for _, f in ipairs(focuses) do
        result = result:union(f)
    end
    return result
end 

function namedfocus.from_name(focusname)
    return Focus.named[focusname]
end 

function namedfocus.from_vexid(vexid)
    return Focus.new(vexid, function() return {vexdex.index[vexid]} end)
end 

function namedfocus.from_file_path(path)
    local vexid = path:gsub(".*/", "")
    return Focus.new(path, function() return {vexdex.index[vexid]} end)
end 

local function recursive_dir_walk(path, paths)
    paths = paths or {}
    local files = lfs.readdir(path)
    for _, file in ipairs(files) do 
        if lfs.attributes(file, "mode") == "file" then 
            table.insert(paths, file)
        elseif lfs.attributes(file, "mode") == "directory" then 
            recursive_dir_walk(file, paths)
        end 
    end 
    return paths
end

function namedfocus.from_folder_path(path)
    return Focus.new(path, function() 
        local tasks = {}
        -- walk through path recursively 
        local files = recursive_dir_walk(path)
        for _, file in ipairs(files) do 
            table.insert(tasks, namedfocus.from_file_path(path))
        end 
        return tasks
    end)
end 

function namedfocus.focus(focusname)
    if focusname:find(",") then
        return namedfocus.from_comma_sep(focusname)
    end 
    if Focus.named[focusname] then 
        return namedfocus.from_name(focusname)
    end 
    if vexdex.index[focusname] then
        return namedfocus.from_vexid(focusname)
    end 
    if type(focusname) == "string" and focusname:find("/") then
        local attr = lfs.attributes(focusname, "mode")
        if attr == "file" then
            return namedfocus.from_file_path(focusname)
        elseif attr == "directory" then
            return namedfocus.from_folder_path(focusname)
        end
    end 
    if focusname == 'prev' then 
        return Focus.read()
    end 
    cli:throw('unknown-focus', focusname)
end 

function Focus.focus(...)
    local focusnames = {...}
    if not focusnames[1] then focusnames = {'prev'} end 
    local focus = namedfocus.focus(table.remove(focusnames, 1))
    for _, focusname in ipairs(focusnames) do
        focus:union(namedfocus.focus(focusname))
    end
    return focus
end

-----------------------------------------
-- API 
-----------------------------------------

-- select comma,sep,values
function Focus:select(...)
    local fields = {...}
    table.insert(fields, 'vexid') -- can't remove this one
    return self:chain('select', function(tasks)
        local tasklist = {}
        for _, task in ipairs(tasks) do
            local newtask = {}
            for _, field in ipairs(fields) do
                newtask[field] = task[field]
            end
            table.insert(tasklist, newtask)
        end
        return tasklist
    end, ...)
end 

-- filter key:value
function Focus:filter(field, value)
    if value == nil then 
        cli:throw('usage', 'You need to provide a field and value to filter on. We saw field = ' .. tostring(field) .. ' and value ' .. tostring(value)) 
    end 
    return self:chain('filter', function(tasks)
        return func.ifilter(tasks, function(task) return task[field] == value end)
    end, field, value)
end 

-- fuzzy key:value 
local function levenshtein(a, b)
    local la, lb = #a, #b
    local dist = {}
    for i = 0, la do
        dist[i] = {}
        dist[i][0] = i  -- was: dist[i] = {i}, which sets dist[i][1], not dist[i][0]
    end
    for j = 0, lb do dist[0][j] = j end
    for i = 1, la do
        for j = 1, lb do
            local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
            dist[i][j] = math.min(
                dist[i - 1][j] + 1,
                dist[i][j - 1] + 1,
                dist[i - 1][j - 1] + cost
            )
        end
    end
    return dist[la][lb]
end

local function levenshtein_less_than_equal_to(fuzz, text, n)
    if type(text) ~= "string" then return false end
    if #text < #fuzz then
        local wlen = #text
        for i = 1, #fuzz - wlen + 1 do
            if levenshtein(fuzz:sub(i, i + wlen - 1), text) <= n then
                return true
            end
        end
        return false
    end
    local len = #fuzz
    for i = 1, #text - len + 1 do
        if levenshtein(text:sub(i, i + len - 1), fuzz) <= n then
            return true
        end
    end
    return false
end 

function Focus:fuzzy(field, fuzz, n)
    n = n or 3
    return self:chain('fuzzy', function(tasks) 
        return func.ifilter(tasks, function(task) return levenshtein_less_than_equal_to(fuzz, task[field], n) end)
    end, field, fuzz, n)
end 

-- between field:begin:end
function Focus:between(field, start, finish)
    return self:chain('between', function(tasks) 
        return func.ifilter(tasks, function(task) 
            return (not start or start <= task[field]) and (not finish or task[field] <= finish)
        end)
    end, field, start, finish)
end 

-- tree field
local function get_children(field)
    return function(task) 
        if type(task[field]) == "string" then return {Focus.getalltasks()[task[field]]} end
        local children = {}
        for _, child in ipairs(task[field]) do
            table.insert(children, Focus.getalltasks()[child])
        end 
        return children
    end 
end

function Focus:tree(field)
    return self:chain('tree', function(tasks) 
        return optic.traverse(get_children(field)):get(tasks)
    end, field)
end

-- reversetree
local function get_parents(field)
    return function(task) 
        local parents = {}
        for _, parent in pairs(Focus.getalltasks()) do
            if type(parent[field]) == "string" and parent[field] == task.vexid then 
                table.insert(parents, parent)
            else 
                for _, parentschild in ipairs(parent[field]) do
                    if parentschild == task.vexid then 
                        table.insert(parents, parent)
                    end
                end 
            end 
        end
        return parents
    end 
end

function Focus:reversetree(field)
    return self:chain('reversetree', function(tasks) 
        return optic.traverse(get_parents(field)):get(tasks)
    end, field)
end

-----------------------------------------
-- Modifiers
-----------------------------------------

-- interpret before any flag will convert values where possible. E.g. `--interpret --filter due:tomorrow` will check for tasks due tomorrow.
function Focus:interpret()
    assert(false, "this is a hard feature that I don't know how to do yet ... for later down the track")
end 

-----------------------------------------
-- Universal 
-----------------------------------------

function Focus:get(tasks)
    return self._get(tasks or Focus.getalltasks())
end

function Focus:each_task(f, ...)
    for _, task in ipairs(self:get()) do
        f(task, ...)
    end
    return self
end

function Focus:each(f, ...)
    for _, task in ipairs(self:get()) do
        f(task.vexid, ...)
    end
    return self
end

-----------------------------------------
-- Parsing
-----------------------------------------

local function split(str, sep)
    local parts = {}
    for part in str:gmatch('([^' .. sep .. ']+)') do
        table.insert(parts, part)
    end
    return unpack(parts)
end

function Focus.parse(args)
    local current
    if type(args[1]) == "string" then 
        current = Focus.focus(args[1])
    else 
        current = Focus.read()
    end 
    if not current then cli:error('no-focus') end
    for _, arg in ipairs(args) do
        if type(arg) == "table" then 
            local f = table.remove(arg, 1)
            local split_args = {}
            for _, a in ipairs(arg) do
                for _, part in ipairs({ split(a, ':') }) do
                    table.insert(split_args, part)
                end
            end
            current = current[f](current, unpack(split_args))
        end 
    end
    return current
end

-----------------------------------------
-- Saving
-----------------------------------------

local function deserialize(saved)
    local f
    for _, op in ipairs(saved.operations) do
        if op.operation == 'focus' then
            f = Focus.focus(unpack(op.args))
        else
            f = f[op.operation](f, unpack(op.args))
        end
    end
    return f
end

function Focus.read()
    local saved = vexdex:getfocus()
    if not saved or not saved.operations then 
        cli:throw('no-focus', 'Recreate your focus.')
    end
    return deserialize(saved)
end

local function serialize(focus)
    return { operations = focus.operations }
end

function Focus:write()
    vexdex:setfocus(serialize(self))
end

-- function Focus.read()
--     local f = vexdex:getfocus()
--     if not f._get or type(f._get) ~= 'function' then return Focus.focus('none') end
--     return Focus.new(f._get)
-- end

-- function Focus:write()
--     vexdex:setfocus(self)
-- end

-- namedfocus(all)
--     :select("vexid", "description", "due")
--     :or():select("importance", "options", "status")
--     :between("due", "2025-01-01", "2026-01-01")
--     :fuzzy("vexid", "hello")
--     :or():fuzzy("vexid", "hello")
--     :or():interpret():filter("due", "tomorrow")
--     :or():interpret():between("due", "tomorrow", "monday")
--     :reversetree("parent")
--     :notin():namedfocus("hello-world-1", "hellow-world-2")

return Focus