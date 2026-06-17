
local cli = require 'lib.cli'
local func = require 'lib.func'
local pretty = require 'lib.pretty'
local plugin = require 'lib.plugin'
local sortdata = plugin:get 'sortdata'
local format = require 'lib.format'
local Focus = require 'core.focus'

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
function View:display(viewname, focus, flags)
    if not self.views[viewname] then cli:throw('unknown-view', viewname) end 
    return self.views[viewname].display(focus, flags)
end

-- only need one
local v = View.new()

v:view 'csv' {
    display = function(focus, flags)
        local tasks = focus:get()
        return format.csv(tasks)
    end
}

v:view 'tabular' {
    display = function(focus, flags)
        local tasks = func.imap(focus:get(), function(task) 
            return func.filter(task, function(value, key) return key ~= 'vexbody' end)
        end)
        return pretty.tabular(tasks, sortdata)
    end
}

v:view 'json' {
    display = function(focus, flags)
        local tasks = focus:get()
        return format.json(tasks, 2)
    end
}

v:view 'kanban' {
    display = function(focus, flags)
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
        for i in ipairs(statuses[maxfield]) do 
            local row = {}
            for status, vexids in pairs(statuses) do
                row[status] = tostring(vexids[i] or '')
            end
            table.insert(viewable, row)
        end 

        return pretty.tabular(viewable)
    end
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
            if not task.parent then nil_parent = nil_parent + 1 end
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

-- ===== HELPER FUNCTIONS =====

-- Build a top-to-bottom tree diagram showing parents -> current -> children
-- Shows critical path from top parent to current, then all children
-- "aunts/uncles" shown as "..."
local function build_tree_diagram(parents, current_id, field)
    local lines = {}
    
    -- Find root parents (those with no parents themselves)
    local roots = {}
    for _, p in ipairs(parents) do
        local pparents = Focus.getalltasks()[p.vexid] and 
            (function()
                local pp = {}
                for _, gp in pairs(Focus.getalltasks()) do
                    if type(gp[field]) == "string" and gp[field] == p.vexid then
                        table.insert(pp, gp)
                    end
                end
                return pp
            end)()
        if not pparents or #pparents == 0 then
            table.insert(roots, p)
        end
    end
    
    -- Walk down from roots to current
    local function walk_down(node, path, depth)
        table.insert(path, node)
        if node.vexid == current_id then
            return path
        end
        -- Find children of this node
        local children = {}
        for _, child_id in ipairs(node[field] or {}) do
            local child = Focus.getalltasks()[child_id]
            if child then table.insert(children, child) end
        end
        for _, child in ipairs(children) do
            local result = walk_down(child, table.copy(path), depth + 1)
            if result then return result end
        end
        return nil
    end
    
    for _, root in ipairs(roots) do
        local path = walk_down(root, {}, 0)
        if path then
            for i, node in ipairs(path) do
                local prefix = ""
                for j = 1, i - 1 do
                    prefix = prefix .. "    "
                end
                if node.vexid == current_id then
                    table.insert(lines, pretty.string(prefix .. "▼ " .. tostring(node.vexid), 'bold', 'bright_yellow'))
                else
                    table.insert(lines, prefix .. "├── " .. tostring(node.vexid))
                end
            end
            break
        end
    end
    
    -- Show children of current
    local children = focus:tree(field)
    if #children > 0 then
        for _, child in ipairs(children) do
            table.insert(lines, "    └── " .. tostring(child.vexid))
        end
    end
    
    return lines
end

-- Build a left-to-right DAG diagram showing dependency chain
-- Shows: furthest parents -> ... -> immediate parents -> current -> immediate children -> ... -> furthest children
local function build_dag_diagram(immediate_parents, current_id)
    local lines = {}
    
    -- Collect all ancestor levels
    local levels = {}  -- levels[0] = furthest parents, levels[-1] = immediate parents
    local visited = {}
    
    local function collect_ancestors(node, level)
        if visited[node.vexid] then return end
        visited[node.vexid] = true
        levels[level] = levels[level] or {}
        table.insert(levels[level], node)
        
        -- Find this node's parents
        for _, gp in pairs(Focus.getalltasks()) do
            if type(gp.dependencies) == "table" then
                for _, dep in ipairs(gp.dependencies) do
                    if dep == node.vexid then
                        collect_ancestors(gp, level - 1)
                    end
                end
            end
        end
    end
    
    for _, p in ipairs(immediate_parents) do
        collect_ancestors(p, -1)
    end
    
    -- Find min level for furthest ancestors
    local min_level = 0
    for level, nodes in pairs(levels) do
        if level < min_level then min_level = level end
    end
    
    -- Print levels left to right
    for level = min_level, -1 do
        local nodes = levels[level]
        if nodes then
            for _, node in ipairs(nodes) do
                if node.vexid == current_id then
                    table.insert(lines, pretty.string("  " .. tostring(node.vexid) .. "  ", 'bold', 'bright_yellow'))
                else
                    table.insert(lines, "  " .. tostring(node.vexid) .. "  ")
                end
            end
        end
    end
    
    -- Current
    table.insert(lines, pretty.string("  ▼ " .. current_id .. "  ", 'bold', 'bright_yellow'))
    
    -- Children
    local children = focus:tree('dependencies')
    if #children > 0 then
        for _, child in ipairs(children) do
            table.insert(lines, "  " .. tostring(child.vexid) .. "  ")
        end
    end
    
    return lines
end


v:view 'singular' {
    display = function(focus, flags)
        local tasks = focus:get()
        if #tasks > 1 then cli:throw('usage', 'The view of singular only accepts focuses which have a single task in them.') end 
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

        -- ===== TREE DIAGRAM (top-to-bottom: parents -> task -> children) =====
        add(pretty.string("PARENTS", 'bold', 'bright_cyan'))
        add("")
        local parents = focus:reversetree('children')
        if #parents > 0 then
            local tree_lines = build_tree_diagram(focus, parents, task.vexid, "children")
            for _, l in ipairs(tree_lines) do
                add(l)
            end
        else
            add("  (no parents)")
        end

        -- ===== DAG DIAGRAM (left-to-right: dependencies) =====
        add("")
        add(pretty.string("DEPENDENCIES", 'bold', 'bright_green'))
        add("")
        local deps = focus:reversetree('dependencies')
        if #deps > 0 then
            local dag_lines = build_dag_diagram(focus, deps, task.vexid)
            for _, l in ipairs(dag_lines) do
                add(l)
            end
        else
            add("  (no dependencies)")
        end

        return table.concat(lines, "\n")
    end
}

return v