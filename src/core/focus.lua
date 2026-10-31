
local func = require 'lib.func'
local lfs = require 'lib.lfs'
local lfsext = require 'lib.lfsext'
local cli = require 'lib.cli'
local pretty = require 'lib.pretty'
local vexdex = require 'core.vexdex'
local event = require 'lib.event'

local Focus = {
    named = {}
}
Focus.__index = Focus

local Groups = {}

local function leaves(tasks, f)
    if getmetatable(tasks) ~= Groups then return f(tasks) end
    local groups = setmetatable({}, Groups)
    for _, group in ipairs(tasks) do
        local result = leaves(group.tasks, f)
        if #result > 0 then table.insert(groups, {field = group.field, value = group.value, tasks = result}) end
    end
    return groups
end

local function flatten(tasks)
    if getmetatable(tasks) ~= Groups then return tasks end
    local tasklist = {}
    for _, group in ipairs(tasks) do tasklist = func.imerge(tasklist, flatten(group.tasks)) end
    return tasklist
end

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
    return func.imap((vexdex:updated()), function(vexid) return vexdex.index[vexid] end)
end)

for _, phase in ipairs {'initial', 'interim', 'final'} do
    Focus.register_focus(phase, function()
        return func.ifilter(Focus.getalltasks(), function(task) return task.phase == phase end)
    end)
end

Focus.register_focus('ready', function()
    return func.ifilter(Focus.getalltasks(), function(task) return task.phase ~= 'final' and #task.blockers == 0 end)
end)

-----------------------------------------
-- Binary Operations
-----------------------------------------

local deserialize

local function asfocus(focus)
    if type(focus) == "string" then return Focus.focus(focus) end
    if getmetatable(focus) ~= Focus then return deserialize(focus) end
    return focus
end

function Focus:chain(operation, focus, ...)
    if type(focus) == "function" then 
        focus = Focus.new(operation, focus)
    end 
    return Focus.new('chain', function(tasks) 
        return leaves(self:result(tasks), function(list) return focus:result(list) end)
    end, func.imerge(self.operations or {}, {{ operation = operation, args = {...} }}))
end

function Focus:intersect(focus)
    focus = asfocus(focus)
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
    focus = asfocus(focus)
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
    focus = asfocus(focus)
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
    focus = asfocus(focus)
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
    focus = asfocus(focus)
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
    end, func.imerge(self.operations or {}, {{ operation = 'onlyin', args = {{ name = focus.name, operations = focus.operations }}}}))
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
-- `updated` for the tasks whose files changed since vex last saw them
-- a list of the above unions them

local namedfocus = {}

function namedfocus.from_name(focusname)
    return Focus.named[focusname]
end 

function namedfocus.from_vexid(vexid)
    return Focus.new(vexid, function() return {vexdex.index[vexid]} end)
end 

local function tasksat(paths)
    local tasks = {}
    for _, path in ipairs(paths) do
        local task = require('core.task'):readfrompath(path)
        if task and vexdex.index[task.vexid] then table.insert(tasks, vexdex.index[task.vexid]) end
    end
    return tasks
end

function namedfocus.from_file_path(path)
    return Focus.new(path, function() return tasksat({path}) end)
end 

function namedfocus.from_folder_path(path)
    return Focus.new(path, function() return tasksat(lfsext.walk(path)) end)
end 

function namedfocus.focus(focusname)
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

function Focus.focus(focusname, ...)
    if select('#', ...) > 0 then return Focus.focus({focusname, ...}) end
    if type(focusname) ~= "table" then return namedfocus.focus(focusname or 'prev') end
    local focus = namedfocus.focus(focusname[1])
    for i = 2, #focusname do
        focus = focus:union(namedfocus.focus(focusname[i]))
    end
    return Focus.new(focusname, function(tasks) return focus:get(tasks) end)
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

local function normalised(task, field, value)
    local fieldschema = value and require('core.task'):schemaof(task.vextype, field)
    if not fieldschema then return value end
    local ok, result = pcall(fieldschema.prevalidate, fieldschema, value, {})
    if ok and result ~= nil then value = result end
    if type(value) ~= type(task[field]) then
        local interpreted, phrase = pcall(fieldschema.unapply, fieldschema, 'interpret', value)
        if not interpreted then cli:throw('uninterpretable', field, phrase) end
        value = phrase
    end
    if type(value) ~= type(task[field]) then
        cli:throw('usage', 'Cannot compare `' .. field .. '` with `' .. tostring(value) .. '`.')
    end
    return value
end

-- filter key:value
function Focus:filter(field, value)
    if value == nil then 
        cli:throw('usage', 'You need to provide a field and value to filter on. We saw field = ' .. tostring(field) .. ' and value ' .. tostring(value)) 
    end 
    return self:chain('filter', function(tasks)
        return func.ifilter(tasks, function(task)
            return task[field] ~= nil and task[field] == normalised(task, field, value)
        end)
    end, field, value)
end 

-- nil field keeps the tasks that hold no value for the field
Focus['nil'] = function(self, field)
    if field == nil then cli:throw('usage', 'You need to provide a field to check for nil.') end
    return self:chain('nil', function(tasks)
        return func.ifilter(tasks, function(task) return task[field] == nil end)
    end, field)
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

-- between field:begin:end, where an empty begin or end leaves that side open
function Focus:between(field, start, finish)
    return self:chain('between', function(tasks) 
        return func.ifilter(tasks, function(task) 
            local value = task[field]
            if value == nil then return false end
            local lower, upper = normalised(task, field, start ~= '' and start), normalised(task, field, finish ~= '' and finish)
            return (not lower or lower <= value) and (not upper or value <= upper)
        end)
    end, field, start, finish)
end 

local function sortkey(value)
    if type(value) == "table" then return table.concat(value, ",") end
    if type(value) == "boolean" then return tostring(value) end
    return value
end

-- -1, 0 or 1 as x sorts before, with or after y; a missing value sorts last either way
local function compare(x, y, descending)
    x, y = sortkey(x), sortkey(y)
    if x == y then return 0 end
    if x == nil then return 1 end
    if y == nil then return -1 end
    if descending then x, y = y, x end
    if type(x) ~= type(y) then x, y = type(x), type(y) end
    return x < y and -1 or 1
end

local function orderings(...)
    local orders = {}
    for _, word in ipairs({...}) do
        if (word == 'asc' or word == 'desc') and #orders > 0 then
            orders[#orders].descending = word == 'desc'
        else
            table.insert(orders, {field = word})
        end
    end
    return orders
end

-- -1, 0 or 1 as task a sorts before, with or after task b
local function order(a, b, orders)
    for _, o in ipairs(orders) do
        local comparison = compare(a[o.field], b[o.field], o.descending)
        if comparison ~= 0 then return comparison end
    end
    return 0
end

-- orderby field[:asc|:desc]:field..., keeping tied tasks in order
function Focus:orderby(...)
    local orders = orderings(...)
    return self:chain('orderby', function(tasks)
        local positions = {}
        for i, task in ipairs(tasks) do positions[task] = i end
        local ordered = func.imap(tasks, function(task) return task end)
        table.sort(ordered, function(a, b)
            local comparison = order(a, b, orders)
            if comparison ~= 0 then return comparison < 0 end
            return positions[a] < positions[b]
        end)
        return ordered
    end, ...)
end

local function count(operation, n)
    local number = tonumber(n)
    if not number or number < 1 or number % 1 ~= 0 then
        cli:throw('usage', 'You need to provide a whole number above zero to ' .. operation .. '. We saw ' .. tostring(n) .. '.')
    end
    return number
end

-- first n keeps the first n tasks, in the order given
function Focus:first(n)
    local number = count('first', n)
    return self:chain('first', function(tasks) return func.first(tasks, number) end, n)
end

-- last n keeps the last n tasks, in the order given
function Focus:last(n)
    local number = count('last', n)
    return self:chain('last', function(tasks) return func.last(tasks, number) end, n)
end

local function bucket(tasks, orders)
    if #orders == 0 then return tasks end
    local o = orders[1]
    local groups, keyed = setmetatable({}, Groups), {}
    for _, task in ipairs(tasks) do
        local key = tostring(sortkey(task[o.field]))
        if not keyed[key] then
            keyed[key] = {field = o.field, value = task[o.field], tasks = {}}
            table.insert(groups, keyed[key])
        end
        table.insert(keyed[key].tasks, task)
    end
    table.sort(groups, function(a, b) return compare(a.value, b.value, o.descending) < 0 end)
    for _, group in ipairs(groups) do group.tasks = bucket(group.tasks, {unpack(orders, 2)}) end
    return groups
end

-- groupby field[:asc|:desc]:field..., ordering the groups as orderby would
function Focus:groupby(...)
    local orders = orderings(...)
    return self:chain('groupby', function(tasks)
        return bucket(tasks, orders)
    end, ...)
end

-- rn numbers each group's tasks from 1 in the field `rn`, on copies of the tasks
function Focus:rn()
    return self:chain('rn', function(tasks)
        return func.imap(tasks, function(task, i)
            local numbered = setmetatable({}, getmetatable(task))
            for field, value in pairs(task) do numbered[field] = value end
            numbered.rn = i
            return numbered
        end)
    end)
end

-- tree field
-- the vexids a task holds across the given fields
local function links(task, fields)
    local linked = {}
    for _, field in ipairs(fields) do
        if type(task[field]) == "string" then
            table.insert(linked, task[field])
        elseif type(task[field]) == "table" then
            for _, vexid in ipairs(task[field]) do table.insert(linked, vexid) end
        end
    end
    return linked
end

local function assertfields(operation, ...)
    local fields = {...}
    if #fields == 0 then cli:throw('usage', 'You need to provide a field to ' .. operation .. ' along.') end
    return fields
end

local function byvexid()
    local tasks = {}
    for _, task in ipairs(Focus.getalltasks()) do tasks[task.vexid] = task end
    return tasks
end

local function get_children(fields)
    local tasks = byvexid()
    return function(task) 
        local children = {}
        for _, child in ipairs(links(task, fields)) do
            table.insert(children, tasks[child])
        end 
        return children
    end 
end

local function walk(tasks, linksof)
    local walked = {}
    local function visit(task, visited)
        visited[task] = true
        table.insert(walked, task)
        for _, linked in ipairs(linksof(task)) do
            if not visited[linked] then visit(linked, visited) end
        end
    end
    for _, task in ipairs(tasks) do visit(task, {}) end
    return walked
end

function Focus:tree(...)
    local fields = assertfields('tree', ...)
    return self:chain('tree', function(tasks) 
        return walk(tasks, get_children(fields))
    end, ...)
end

-- reversetree
local function get_parents(fields)
    local alltasks = Focus.getalltasks()
    return function(task) 
        return func.ifilter(alltasks, function(parent)
            for _, child in ipairs(links(parent, fields)) do
                if child == task.vexid then return true end
            end
            return false
        end)
    end 
end

function Focus:reversetree(...)
    local fields = assertfields('reversetree', ...)
    return self:chain('reversetree', function(tasks) 
        return walk(tasks, get_parents(fields))
    end, ...)
end

-- step field...
function Focus:step(...)
    local fields = assertfields('step', ...)
    return self:chain('step', function(tasks)
        local children = get_children(fields)
        local stepped, seen = {}, {}
        for _, task in ipairs(tasks) do
            for _, linked in ipairs(children(task)) do
                if not seen[linked] then
                    seen[linked] = true
                    table.insert(stepped, linked)
                end
            end
        end
        return stepped
    end, ...)
end

-----------------------------------------
-- Universal 
-----------------------------------------

function Focus:result(tasks)
    return self._get(tasks or Focus.getalltasks())
end

function Focus:get(tasks)
    return flatten(self:result(tasks))
end

function Focus.isgrouped(tasks)
    return getmetatable(tasks) == Groups
end

function Focus:groups(tasks)
    local groups = {}
    leaves(self:result(tasks), function(list)
        if #list > 0 then table.insert(groups, list) end
        return list
    end)
    return groups
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
    for part in (str .. sep):gmatch('(.-)' .. sep) do
        table.insert(parts, part)
    end
    return unpack(parts)
end

function Focus:apply(args)
    local current = self
    for _, arg in ipairs(args) do
        if cli.isflag(arg) then 
            if type(Focus[arg[1]]) ~= "function" then cli:throw('unknown-focus-operation', arg[1]) end
            local split_args = {}
            local values = type(arg[2]) == "table" and arg[2] or {arg[2]}
            for _, value in ipairs(values) do
                for _, part in ipairs({ split(value, ':') }) do
                    table.insert(split_args, part)
                end
            end
            current = current[arg[1]](current, unpack(split_args))
        end 
    end
    return current
end

function Focus.parse(args)
    local current
    if args[1] and not cli.isflag(args[1]) then 
        current = Focus.focus(args[1])
    else 
        current = Focus.read()
    end 
    if not current then cli:throw('no-focus') end
    return current:apply(args)
end

-----------------------------------------
-- Saving
-----------------------------------------

function deserialize(saved)
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
    event:trigger('pre-focus-write', self)
    vexdex:setfocus(serialize(self))
    event:trigger('post-focus-write', self)
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
--     :or():filter("due", "tomorrow")
--     :or():between("due", "tomorrow", "monday")
--     :reversetree("parent")
--     :notin():namedfocus("hello-world-1", "hellow-world-2")

return Focus