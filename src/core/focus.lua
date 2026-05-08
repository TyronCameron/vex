
local func = require 'lib.func'
local optic = require 'lib.optic'
local lfs = require 'lib.lfs'
local cli = require 'lib.cli'

local Focuses = {}
local vexdex = nil 
local Tasks = nil

local Focus = {}
Focus.__index = Focus

function Focus.new(get)
    return setmetatable({_get = get}, Focus)    
end

function Focus.register_focus(name, get)
    Focuses[name] = Focus.new(get)
end

function Focus.init(vexdex)
    vexdex = vexdex
    Tasks = func.values(vexdex.index)
end

-----------------------------------------
-- Binary Operations 
-----------------------------------------

function Focus:chain(focus)
    if type(focus) == "function" then 
        focus = Focus.new(focus)
    end 
    return Focus.new(function(tasks) 
        return focus:get(self:get(tasks))
    end)
end

function Focus:intersect(focus)
    return Focus.new(function(tasks) 
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
    end)
end 

function Focus:union(focus)
    return Focus.new(function(tasks) 
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
    end)
end 

function Focus:complement()
    return Focus.new(function(tasks) 
        local tasklist = {}
        local hash = {}
        for _, task in ipairs(self:get(tasks)) do 
            hash[task] = true 
        end 
        for _, task in pairs(Tasks) do
            if not hash[task] then table.insert(tasklist, task) end 
        end
        return tasklist 
    end)
end 

function Focus:xor(focus)
    return Focus.new(function(tasks) 
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
    end)
end 

function Focus:notin(focus)
    return Focus.new(function(tasks) 
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
    end)
end 

function Focus:onlyin(focus)
    return Focus.new(function(tasks) 
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
-- Named Focuses
-----------------------------------------

-- Examples:
-- `prev` which saves the previous focus used. For conciseness, this is the default focus. If no `prev` is available, it uses `none` instead. This applies in all cases except for `focus` itself. 
-- `all`
-- `none`
-- `tag` for any task tag 
-- `path` for any task path (if there is a slash)
-- `updated` for only tasks which have updated against the index. 
-- comma separation of the above is allowed so as to union them

Focus.register_focus("all", function() return Tasks end)
Focus.register_focus("none", function() return {} end)
Focus.register_focus("prev", function(tasks) return  end)
Focus.register_focus("updated", function() return func.filter(Tasks, function(task) return task.modified > vexdex.modified end) end)

local function get_focus_from_name(focusname)
    return Focuses[focusname]
end 

local function get_focus_from_vexid(vexid)
    return Focus.new(function() return Tasks[vexid] end)
end 

local function get_focus_from_file_path(path)
    local vexid = path:gsub(".*/", "")
    return Focus.new(function() return Tasks[vexid] end)
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

local function get_focus_from_folder_path(path)
    return Focus.new(function() 
        local tasks = {}
        -- walk through path recursively 
        local files = recursive_dir_walk(path)
        for _, file in ipairs(files) do 
            table.insert(tasks, get_focus_from_file_path(path))
        end 
        return tasks
    end)
end 

local function get_named_focus(focusname)
    if focusname == 'prev' then return vexdex:getfocus():get(tasks) end 
    if Focuses[focusname] then 
        return get_focus_from_name(focusname)
    end 
    if vexdex.index[focusname] then
        return get_focus_from_vexid(focusname)
    end 
    if type(focusname) == "string" and focusname:find("/") then
        local attr = lfs.attributes(focusname, "mode")
        if attr == "file" then
            return get_focus_from_file_path(focusname)
        elseif attr == "directory" then
            return get_focus_from_folder_path(focusname)
        end
    end 
    assert(false, "Oh no, this focus is broken!")
end 

function Focus.focus(...)
    local focusnames = {...}
    assert(#focusnames >= 1, 'Focus by name needs at least one focus') 
    local focus = get_named_focus(table.remove(focusnames, 1))
    for _, focusname in ipairs(focusnames) do
        focus:union(get_named_focus(focusname))
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
    return self:chain(function(tasks)
        local tasklist = {}
        for _, task in ipairs(tasks) do
            local newtask = {}
            for _, field in ipairs(fields) do
                newtask[field] = task[field]
            end
            table.insert(tasklist, newtask)
        end
        return tasklist
    end)
end 

-- filter key:value
function Focus:filter(field, value)
    return self:chain(function(tasks)
        return func.ifilter(tasks, function(task) return task[field] == value end)
    end)
end 

-- fuzzy key:value 
local function levenshtein(a, b)
    local la, lb = #a, #b
    local dist = {}
    for i = 0, la do dist[i] = {i} end
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
    return self:chain(function(tasks) 
        return func.ifilter(tasks, function(task) return levenshtein_less_than_equal_to(fuzz, task[field], n) end)
    end)
end 

-- between field:begin:end
function Focus:between(field, start, finish)
    return self:chain(function(tasks) 
        return func.ifilter(tasks, function(task) return start <= task[field] and task[field] <= finish end)
    end)
end 

-- tree field
local function get_children(field)
    return function(task) 
        if type(task[field]) == "string" then return {Tasks[task[field]]} end
        local children = {}
        for _, child in ipairs(task[field]) do
            table.insert(children, Tasks[child])
        end 
        return children
    end 
end

function Focus:tree(field)
    return self:chain(function(tasks) 
        return optic.traverse(get_children(field)):get(tasks)
    end)
end

-- reversetree
local function get_parents(field)
    return function(task) 
        local parents = {}
        for _, parent in pairs(Tasks) do
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

function Focus:tree(field)
    return self:chain(function(tasks) 
        return optic.traverse(get_parents(field)):get(tasks)
    end)
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

function Focus:get(...)
    return self._get(...)
end

function Focus:map(tasks, f)
    for _, task in ipairs(self:get(tasks)) do
        f(task)
    end
    return self
end

-----------------------------------------
-- Parsing
-----------------------------------------

function Focus.parse(args)
    local current
    if type(args[1]) == "string" then 
        current = Focus.focus(args[1])
    else 
        current = vexdex:getfocus()
    end 
    if not current then cli:error('no-focus') end
    for _, arg in ipairs(args) do
        if type(arg) == "table" then 
            f = table.remove(arg, 1)
            current = current[f](current, unpack(arg))
        end 
    end
    return current
end

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