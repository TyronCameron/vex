
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

-- every field the tasks hold, and those the focus selects, so a column shows for a transient such as an abstract's status
local function columns(focus, tasks)
    local found = {}
    for _, t in ipairs(tasks) do
        for k in pairs(t) do if k ~= 'vexbody' then found[k] = true end end
    end
    for _, k in ipairs(focus:selected() or {}) do found[k] = true end
    return found
end

-- a task's value for each column, formatted, read through its transients where it stores none
local function row(t, cols, raw)
    local formatted = task:format(t.vexid)
    local result = {}
    for k in pairs(cols) do
        local v = rawget(t, k)
        local value = (raw and type(v) == 'string') and v or formatted[k]
        if value == nil then value = v end
        if value == nil then value = '' end
        result[k] = value
    end
    return result
end

v:view 'csv' {
    display = function(focus, flags)
        local tasks = focus:get()
        local cols = columns(focus, tasks)
        return format.csv(func.imap(tasks, function(t) return row(t, cols, true) end))
    end
}

local function isdate(t, field)
    local fieldschema = task:schemaof(t.vextype, field)
    if not fieldschema then return false end
    local value = t[field]
    return #fieldschema:collect('datetime', value) + #fieldschema:collect('date', value) > 0
end

local function icstime(epoch, allday)
    if allday then return {params = 'VALUE=DATE', value = os.date('%Y%m%d', epoch)} end
    return {value = os.date('!%Y%m%dT%H%M%SZ', math.floor(epoch))}
end

local function atmidnight(epoch)
    local t = os.date('*t', epoch)
    return t.hour == 0 and t.min == 0 and t.sec == 0
end

v:view 'ics' {
    display = function(focus, flags)
        local field = flags.by or 'due'
        local events = {}
        for _, t in ipairs(focus:get()) do
            local epoch = t[field]
            if epoch ~= nil then
                if not isdate(t, field) then cli:throw('not-a-date-field', field) end
                local fields = row(t, columns(focus, {t}), true)
                local allday = atmidnight(epoch)
                local start = icstime(epoch, allday)
                local event = {
                    {name = 'UID', value = t.vexid .. '@vex'},
                    {name = 'DTSTAMP', value = icstime(t.modified or os.time()).value},
                    {name = 'DTSTART', value = start.value, params = start.params},
                    {name = 'SUMMARY', value = t.description, text = true},
                }
                if allday then
                    table.insert(event, {name = 'DTEND', value = icstime(epoch + 86400, true).value, params = start.params})
                end
                if t.created then table.insert(event, {name = 'CREATED', value = icstime(t.created).value}) end
                if t.modified then table.insert(event, {name = 'LAST-MODIFIED', value = icstime(t.modified).value}) end
                local lineage = t.lineage or {}
                if #lineage > 0 then
                    table.insert(event, {name = 'RELATED-TO', params = 'RELTYPE=PARENT', value = lineage[#lineage] .. '@vex'})
                end
                local categories = func.imap(func.ifilter({t.vextype, t.owner}, function(c) return c ~= nil end), function(c) return format.icstext(tostring(c)) end)
                table.insert(event, {name = 'CATEGORIES', value = table.concat(categories, ',')})
                local keys = func.keys(fields)
                table.sort(keys)
                local details = {}
                for _, key in ipairs(keys) do
                    local value = fields[key]
                    if key ~= 'description' and value ~= '' then
                        if type(value) == 'table' then value = table.concat(value, ', ') end
                        table.insert(details, key .. ': ' .. tostring(value))
                    end
                end
                table.insert(event, {name = 'DESCRIPTION', value = table.concat(details, '\n'), text = true})
                table.insert(events, event)
            end
        end
        return format.ics(events, '-//vex//vex view ics//EN')
    end
}

local function tabularrow(t, cols)
    local result = row(t, cols)
    if result.path ~= '' and result.path then result.path = pretty.string(result.path, {filelink = result.path}) end
    return result
end

local function firsttask(tasks)
    if Focus.isgrouped(tasks) then return firsttask(tasks[1].tasks) end
    return tasks[1]
end

local function tabularrows(rows, tasks, depth, cols)
    if not Focus.isgrouped(tasks) then
        for _, t in ipairs(tasks) do table.insert(rows, tabularrow(t, cols)) end
        return rows
    end
    for _, group in ipairs(tasks) do
        local value = task:format(firsttask(group.tasks).vexid)[group.field]
        if value == nil then value = group.value end
        if value == nil then value = '(none)' end
        table.insert(rows, pretty.subheader(group.field, value, depth))
        tabularrows(rows, group.tasks, depth + 1, cols)
    end
    return rows
end

v:view 'tabular' {
    display = function(focus, flags, flagwords)
        local applied = focus:apply(flagwords)
        local tasks = applied:result()
        return pretty.tabular(tabularrows({}, tasks, 0, columns(applied, applied:get())), sortdata)
    end
}

local function aslist(value, default)
    if value == nil then return default end
    return type(value) == "table" and value or {value}
end

local function hasflag(flagwords, name)
    return func.any(flagwords, function(word) return cli.isflag(word) and word[1] == name end)
end

local function listcell(t, field)
    local value = task:format(t.vexid)[field]
    if value == nil then value = t[field] end
    if type(value) == "table" then return table.concat(value, ',') end
    return value == nil and '' or tostring(value)
end

local function listbullet(kind, t, position)
    if kind == 'numbered' then return position .. '.' end
    if kind == 'check' then return t.phase == 'final' and '- [x]' or '- [ ]' end
    return '-'
end

local function descendants(node)
    return func.ifold(node.children, function(total, child) return total + 1 + descendants(child) end, 0)
end

v:view 'list' {
    display = function(focus, flags, flagwords)
        local kind = flags.bullet or '-'
        if not func.any({'-', 'numbered', 'check'}, function(allowed) return allowed == kind end) then
            cli:throw('usage', 'The bullet of the list view is `-`, `numbered` or `check`. We saw ' .. tostring(kind) .. '.')
        end
        local fold = tonumber(flags.fold or 10)
        if not fold then cli:throw('usage', 'The fold of the list view is a number of levels. We saw ' .. tostring(flags.fold) .. '.') end
        local fields, indentby = aslist(flags.fields, {'vexid'}), aslist(flags.indentby, {'children'})
        local sep = type(flags.sep) == "table" and table.concat(flags.sep, ',') or flags.sep or ', '

        local ordering = {}
        for _, word in ipairs(aslist(flags.orderby, {'urgency'})) do
            for part in tostring(word):gmatch('[^:]+') do table.insert(ordering, part) end
        end
        local tasks = Focus.new('list', function() return focus:get() end):orderby(unpack(ordering)):get()

        local infocus, nested = {}, {}
        for _, t in ipairs(tasks) do infocus[t.vexid] = true end
        local nodes = {}
        for _, t in ipairs(tasks) do
            local linked = func.ifilter(Focus.focus(t.vexid):step(unpack(indentby)):get(), function(child) return infocus[child.vexid] end)
            local ids = {}
            for _, child in ipairs(linked) do ids[child.vexid] = true; nested[child.vexid] = true end
            nodes[t.vexid] = {task = t, linked = ids}
        end

        local function build(t)
            local children = {}
            for _, other in ipairs(tasks) do
                if nodes[t.vexid].linked[other.vexid] then table.insert(children, build(other)) end
            end
            return {task = t, children = children}
        end
        local roots = {}
        for _, t in ipairs(tasks) do
            if not nested[t.vexid] then table.insert(roots, build(t)) end
        end

        local rows = {}
        local function walk(siblings, depth)
            for position, node in ipairs(siblings) do
                local bullet = listbullet(kind, node.task, position)
                local cells = func.imap(fields, function(field) return listcell(node.task, field) end)
                cells[1] = string.rep(' ', depth * (kind == 'numbered' and 3 or 2)) .. bullet .. ' ' .. cells[1]
                local hidden = depth + 1 >= fold and descendants(node) or 0
                table.insert(rows, {cells = cells, hidden = hidden})
                if depth + 1 < fold then walk(node.children, depth + 1) end
            end
        end
        walk(roots, 0)

        local widths = {}
        if hasflag(flagwords, 'align') then
            for _, row in ipairs(rows) do
                for i, cell in ipairs(row.cells) do widths[i] = math.max(widths[i] or 0, #cell) end
            end
        end
        local lines = func.imap(rows, function(row)
            local cells = func.imap(row.cells, function(cell, i)
                return i < #row.cells and widths[i] and cell .. string.rep(' ', widths[i] - #cell) or cell
            end)
            return table.concat(cells, sep) .. (row.hidden > 0 and ' (+' .. row.hidden .. ')' or '')
        end)
        return table.concat(lines, "\n")
    end
}

v:view 'json' {
    display = function(focus, flags)
        local tasks = focus:get()
        return format.json(tasks)
    end
}

-- orders statuses by the most moves any task type needs to reach them from its initial state (a type without a status machine counts its phase), then by name
local function bymoves(field, tasks)
    local moves = {}
    if field == 'status' then
        for _, t in ipairs(tasks) do
            local status = task:schemaof(t.vextype, 'status')
            local distances = {[t.status] = ({initial = 0, interim = 1, final = 2})[t.phase]}
            if status and status._name == 'statemachine' then
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

        -- ===== STRUCTURE =====
        add("")
        add(pretty.string("STRUCTURE", "bold", "bright_yellow"))
        add("")
        local nil_parent = 0
        local nil_deps = 0
        for _, task in ipairs(tasks) do
            local lineage = Focus.focus(task.vexid):reversetree('children'):get()
            if #lineage == 1 then nil_parent = nil_parent + 1 end
            if #(task.dependencies or {}) == 0 then nil_deps = nil_deps + 1 end
        end
        add("  Tasks without a parent:       " .. string.format("%.1f%%", nil_parent / #tasks * 100))
        add("  Tasks without dependencies:   " .. string.format("%.1f%%", nil_deps / #tasks * 100))

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
            add("  Earliest task created:        " .. os.date("%Y-%m-%d", math.floor(earliest)))
        else
            add("  Earliest task created:        N/A")
        end
        if latest_mod then
            add("  Latest modification:          " .. os.date("%Y-%m-%d", math.floor(latest_mod)))
        else
            add("  Latest modification:          N/A")
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
        add(pretty.string('# ' .. tostring(task.vexid), 'cyan', 'underline', 'bold'))
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