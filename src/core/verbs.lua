local cli = require "lib.cli"
local focus = require 'core.focus'
local cfg = require 'lib.config'
local func = require 'lib.func'
local pretty = require 'lib.pretty'
local view = require 'core.view'
local recipe = require 'core.recipe'
local vexdex = require 'core.vexdex'
local task = require 'core.task'
require 'core.taskdefinitions'

local function focus_pop_args(args)
    if not cli.isflag(args[1]) then
        return focus.focus(table.remove(args, 1))
    end
    return focus.focus()
end

-- joins accumulated output lines into the verb's return value; nil (rather
-- than "") when there's nothing to say, so a verb that would previously
-- have printed nothing still prints nothing
local function join_lines(lines)
    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

cli:verb "show" {
    function(args)
        local f = focus_pop_args(args)
        local lines = {}
        f:each(function(vexid)
            table.insert(lines, task:show(vexid))
        end)
        return join_lines(lines)
    end,
    doc = "Prints out a task to terminal, highlighting YAML frontmatter and Markdown notes.",
    args = "[focus]",
    example = "vex show make-coffee"
}

cli:verb "focus" {
    function(args)
        local lines = {}
        local function count(f)
            local vex_cnt = #f:get()
            return pretty.string(vex_cnt, "bold") .. (vex_cnt == 1 and " vex" or " vexes")
        end
        if #args == 0 then
            local f = focus.read()
            table.insert(lines, pretty.any('Current focus on ' .. count(f)))
            for _, op in ipairs(f.operations) do
                table.insert(lines, pretty.any(pretty.string(op.operation, 'cyan'), pretty.string('args = ', 'green'), op.args))
            end
        else
            local f = focus.parse(args)
            f:write()
            table.insert(lines, pretty.any("Focusing on " .. count(f)))
        end
        return join_lines(lines)
    end,
    doc = "Creates an focus which can be used as a data query against the vex folder. Provide no args to see the current focus.",
    args = "[focus] [--focusflags...]",
    example = "vex focus all --filter status:done"
}

cli:verb "view" {
    function(args)
        local positional_args = args:positional()

        if #positional_args == 0 then
            local lines = { pretty.any('Available views:') }
            for view in pairs(view.views) do
                table.insert(lines, pretty.any('  ' .. view))
            end
            return join_lines(lines)
        end

        local focusargs, viewname = {}, positional_args[#positional_args > 1 and 2 or 1]
        if #positional_args > 1 then focusargs[1] = positional_args[1] end
        local flags = {}
        for _, word in ipairs(args) do
            if cli.isflag(word) and focus.operates(word[1]) then
                table.insert(focusargs, word)
            elseif cli.isflag(word) and word[2] then
                flags[word[1]] = word[2]
            end
        end
        return view:display(viewname, focus.parse(focusargs), flags)
    end,
    doc = "Prints a view of current tasks. Focus flags shape the focus for this view only, without saving it.",
    args = "[focus] [view] [--focusflags...]",
    example = "vex view all tabular --groupby status --orderby due"
}

cli:verb "resolve" {
    function(args)
        if args[1] == 'all' then 
            task:reindexall()
        end 
        local f = focus_pop_args(args)
        f:each(function(vexid)
            task:resolve(vexid)
        end)
    end,
    doc = "Validates, updates and normalises fields and tasks",
    args = "[focus]",
    example = "vex resolve all"
}

cli:verb "add" {
    function(args)
        local taskproperties = args:flags()
        taskproperties.description = args:text()
        local vexid = task:add(taskproperties)
        task:resolve(vexid)
        task:write(vexid)
        focus.focus(vexid):write()
        return vexid
    end,
    doc = "Creates a task with the Description provided. Automatically fills out some frontmatter and resolves. This outputs and sets the focus to this new tag",
    args = "Description... [--fields...]",
    example = "vex add Make coffee for wife --importance high"
}

cli:verb "remove" {
    function(args)
        local f = focus_pop_args(args)
        local lines = {}
        f:each(function(vexid)
            task:remove(vexid)
            task:delete(vexid)
            table.insert(lines, pretty.any(vexid))
        end)
        vexdex:setfocus(nil)
        focus.focus('all'):each(function(vexid)
            task:resolve(vexid)
        end)
        return join_lines(lines)
    end,
    doc = "Deletes tasks in the focus, and drops your focus. Runs resolve on all linked tasks thereafter. Not recommended for regular use.",
    args = "[focus]",
    example = "vex remove make-coffee"
}

cli:verb "get" {
    function(args)
        local f = focus_pop_args(args)
        local fields = {}
        for _, flag in ipairs(func.ifilter(args, cli.isflag)) do
            if flag[1] == 'select' then
                fields = func.imerge(fields, type(flag[2]) == "table" and flag[2] or {flag[2]})
            elseif not flag[2] then
                table.insert(fields, flag[1])
            end
        end
        if #fields == 0 then fields = {'vexid'} end
        local lines = {}
        f:each(function(vexid)
            table.insert(lines, pretty.any(task:get(vexid, fields)))
        end)
        return join_lines(lines)
    end,
    doc = "Presents the focus in a tangible data format. Can specify which fields by supplying them as flags, or as a comma list to --select",
    args = "[focus] [--fields...]",
    example = "vex get all --select due,vexid,description"
}

cli:verb "set" {
    function(args)
        local f = focus_pop_args(args)
        local taskproperties = args:flags()
        local modifiers = args:modifiers()
        f:each(function(vexid)
            task:set(vexid, taskproperties, modifiers)
            task:resolve(vexid)
            task:write(vexid)
        end)
    end,
    doc = "Allows you to set fields in the focus. Put --insert or --remove before a list field to add or remove values rather than overwrite it. Resolution is called on that `focus`",
    args = "[focus] [--fields...]",
    example = "vex set plan-trip-1 --insert --children book-flights-1,book-hotel-1"
}

cli:verb "recipe" {
    function(args)
        local recipename = table.remove(args, 1)
        if not recipename then
            local lines = { pretty.any('Available recipes:') }
            for recipename in pairs(recipe.recipes) do
                table.insert(lines, pretty.any('  ' .. recipename))
            end
            return join_lines(lines)
        end

        local taskproperties = args:flags()
        taskproperties.description = args:text()

        local f = recipe:add(recipename, taskproperties)
        local lines = {}
        f:each(function(vexid)
            task:write(vexid)
            table.insert(lines, pretty.any(vexid))
        end)
        f:write()
        return join_lines(lines)
    end,
    doc = "Creates a recipe (series of tasks). This outputs and changes the focus",
    args = "[recipe] Description... [--fields...]",
    example = "vex recipe abstract Create more vex tasks! --status todo"
}

require 'core.extensions'
