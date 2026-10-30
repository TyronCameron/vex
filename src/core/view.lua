
local cli = require 'lib.cli'
local func = require 'lib.func'
local pretty = require 'lib.pretty'
local plugin = require 'lib.plugin'
local sortdata = plugin:get 'sortdata'
local format = require 'lib.format'
local Focus = require 'core.focus'
local task = require 'core.task'
local event = require 'lib.event'
local statemachine = require 'lib.statemachine'

local View = {}
View.__index = View

-- create new view manager
function View.new()
    return setmetatable({views = {}}, View)
end 

function View:view(name)
    return function(tab)
        assert(type(tab.display) == "function", "Need to have a function called display to define a view")
        self.views[name] = tab
    end
end

-- actually print stuff to screen
function View:display(viewname, focus, flags, flagwords)
    if not self.views[viewname] then cli:throw('unknown-view', viewname) end 
    event:trigger('pre-view-display', viewname, focus, flags)
    local result = self.views[viewname].display(focus, flags, flagwords or {})
    event:trigger('post-view-display', viewname, focus, flags, result)
    return result
end

-- only need one
local v = View.new()

v:view 'csv' {
    display = function(focus, flags)
        local tasks = focus:get()
        return format.csv(tasks)
    end
}

local function tabularrow(t)
    local formatted = task:format(t.vexid)
    local result = {}
    for k, v in pairs(t) do
        if k ~= 'vexbody' then
            result[k] = formatted[k]
            if result[k] == nil then result[k] = v end
        end
    end
    if result.path then result.path = pretty.string(result.path, {filelink = result.path}) end
    return result
end

local function firsttask(tasks)
    if Focus.isgrouped(tasks) then return firsttask(tasks[1].tasks) end
    return tasks[1]
end

local function tabularrows(rows, tasks, depth)
    if not Focus.isgrouped(tasks) then
        for _, t in ipairs(tasks) do table.insert(rows, tabularrow(t)) end
        return rows
    end
    for _, group in ipairs(tasks) do
        local value = task:format(firsttask(group.tasks).vexid)[group.field]
        if value == nil then value = group.value end
        table.insert(rows, pretty.subheader(group.field, value, depth))
        tabularrows(rows, group.tasks, depth + 1)
    end
    return rows
end

v:view 'tabular' {
    display = function(focus, flags, flagwords)
        return pretty.tabular(tabularrows({}, focus:apply(flagwords):result(), 0), sortdata)
    end
}

v:view 'json' {
    display = function(focus, flags)
        local tasks = focus:get()
        return format.json(tasks, 2)
    end
}

-- orders statuses by the most moves any task type needs to reach them from its initial state (a type without a status machine counts its phase), then by name
local function bymoves(field, tasks)
    local moves = {}
    if field == 'status' then
        for _, t in ipairs(tasks) do
            local status = task:schemaof(t.vextype, 'status')
            local distances = {[t.status] = ({initial = 0, interim = 1, final = 2})[t.phase]}
            if status then
                local machine = statemachine.new(status.specification.states, status.specification.initial, status.specification.initial)
                distances = machine:distances()
            end
            for state, distance in pairs(distances) do
                moves[state] = math.max(moves[state] or 0, distance)
            end
        end
    end
    return function(a, b)
        local x, y = moves[a] or math.huge, moves[b] or math.huge
        if x ~= y then return x < y end
        return tostring(a) < tostring(b)
    end
end

local function kanban(columnorder)
    return function(focus, flags)
        local tasks = focus:get()
        local field = flags.field or 'status'

        local statuses = {}
        for _, task in ipairs(tasks) do 
            statuses[task[field]] = statuses[task[field]] or {}
            table.insert(statuses[task[field]], task.vexid)
        end 

        local maxfield
        local maxlength = 0
        for status, vexids in pairs(statuses) do
            if maxlength < #vexids then 
                maxlength = #vexids
                maxfield = status 
            end 
        end

        local viewable = {}
        for i in ipairs(statuses[maxfield] or {}) do 
            local row = {}
            for status, vexids in pairs(statuses) do
                row[status] = tostring(vexids[i] or '')
            end
            table.insert(viewable, row)
        end 

        local columns = func.keys(statuses)
        table.sort(columns, columnorder(field, tasks))
        return pretty.tabular(viewable, function()
            local i = 0
            return function()
                i = i + 1
                return columns[i]
            end
        end)
    end
end

v:view 'kanban' {
    display = kanban(bymoves)
}

v:view 'overview' {
    display = function(focus, flags)
        local tasks = focus:get()
        local lines = {}
        local function add(s) table.insert(lines, s) end

        -- ===== SCOPE =====
        add(pretty.string("SCOPE", "bold", "bright_cyan"))
        add("")

        -- Collect all vextypes and statuses, and cross-tabulate
        local vextypes = {}
        local statuses = {}
        local cross = {}  -- cross[vt][st] = count
        for _, task in ipairs(tasks) do
            local vt = task.vextype or "(none)"
            local st = task.status or "(none)"
            vextypes[vt] = (vextypes[vt] or 0) + 1
            statuses[st] = true
            cross[vt] = cross[vt] or {}
            cross[vt][st] = (cross[vt][st] or 0) + 1
        end
        -- sort keys
        local vtkeys = func.keys(vextypes)
        table.sort(vtkeys)
        local stkeys = func.keys(statuses)
        table.sort(stkeys)

        -- Build data rows for pretty.tabular
        local scope_rows = {}
        local col_totals = {}
        for _, st in ipairs(stkeys) do col_totals[#col_totals+1] = 0 end
        for _, vt in ipairs(vtkeys) do
            local row = {vextype = vt, total = vextypes[vt]}
            for j, st in ipairs(stkeys) do
                local count = cross[vt][st] or 0
                col_totals[j] = col_totals[j] + count
                row[st] = string.format("%.1f%%", count / vextypes[vt] * 100)
            end
            scope_rows[#scope_rows+1] = row
        end
        -- Add total row
        local totalrow = {vextype = "TOTAL", total = pretty.string(#tasks, "bold")}
        for j, total in ipairs(col_totals) do
            totalrow[stkeys[j]] = string.format("%.1f%%", total / #tasks * 100)
        end
        scope_rows[#scope_rows+1] = totalrow

        add(pretty.tabular(scope_rows, sortdata))

        -- ===== QUALITY =====
        add("")
        add(pretty.string("QUALITY", "bold", "bright_green"))
        add("")
        local no_body = 0
        for _, task in ipairs(tasks) do
            if not task.vexbody or #task.vexbody == 0 then
                no_body = no_body + 1
            end
        end
        add("  Tasks with no vexbody: " .. string.format("%.1f%%", no_body / #tasks * 100))

        -- ===== STRUCTURE =====
        add("")
        add(pretty.string("STRUCTURE", "bold", "bright_yellow"))
        add("")
        local nil_parent = 0
        local nil_deps = 0
        for _, task in ipairs(tasks) do
            local lineage = Focus.focus(task.vexid):reversetree('children'):get()
            if #lineage == 1 then nil_parent = nil_parent + 1 end
            if not task.dependencies then nil_deps = nil_deps + 1 end
        end
        add("  Tasks with nil parent:    " .. string.format("%.1f%%", nil_parent / #tasks * 100))
        add("  Tasks with nil deps:     " .. string.format("%.1f%%", nil_deps / #tasks * 100))

        -- ===== MOVEMENT =====
        add("")
        add(pretty.string("MOVEMENT", "bold", "bright_magenta"))
        add("")
        local earliest = nil
        local latest_mod = nil
        for _, task in ipairs(tasks) do
            if task.created then
                if not earliest or task.created < earliest then
                    earliest = task.created
                end
            end
            if task.modified then
                if not latest_mod or task.modified > latest_mod then
                    latest_mod = task.modified
                end
            end
        end
        if earliest then
            add("  Earliest task created:   " .. os.date("%Y-%m-%d", math.floor(earliest)))
        else
            add("  Earliest task created:   N/A")
        end
        if latest_mod then
            add("  Latest modification:     " .. os.date("%Y-%m-%d", math.floor(latest_mod)))
        else
            add("  Latest modification:     N/A")
        end

        return table.concat(lines, "\n")
    end
}

v:view 'singular' {
    display = function(focus, flags)
        local tasks = focus:get()
        if #tasks ~= 1 then cli:throw('usage', 'The view of singular only accepts focuses which have a single task in them.') end 
        local task = tasks[1]
        
        local lines = {}
        local function add(s) table.insert(lines, s) end

        -- ===== HEADING =====
        add(pretty.string('# ' .. string.upper(tostring(task.vexid)), 'cyan', 'underline', 'bold'))
        add(pretty.string('  ' .. tostring(task.vextype or 'task') .. '  |  ' .. tostring(task.status or 'todo'), 'dim'))
        if task.created then
            add(pretty.string('  created: ' .. os.date('%Y-%m-%d %H:%M', math.floor(task.created)), 'dim'))
        end
        if task.modified and task.modified ~= task.created then
            add(pretty.string('  modified: ' .. os.date('%Y-%m-%d %H:%M', math.floor(task.modified)), 'dim'))
        end
        add("")

        local function related(f)
            return func.ifilter(f:get(), function(t) return t.vexid ~= task.vexid end)
        end
        local function section(title, colour, tasks, nested)
            add(pretty.string(title, 'bold', colour))
            add("")
            if #tasks == 0 then add("  (none)") end
            for i, t in ipairs(tasks) do
                add(string.rep("  ", nested and i or 1) .. tostring(t.vexid))
            end
            add("")
        end

        section("PARENTS", 'bright_cyan', func.reverse(related(focus:reversetree('children'))), true)
        section("CHILDREN", 'bright_cyan', related(focus:tree('children')))
        section("DEPENDS ON", 'bright_green', related(focus:tree('dependencies')))
        section("DEPENDED ON BY", 'bright_green', related(focus:reversetree('dependencies')))

        return table.concat(lines, "\n")
    end
}

return v