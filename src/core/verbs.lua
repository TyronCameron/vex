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
    if type(args[1]) ~= 'table' then 
        return focus.focus(table.remove(args, 1))
    end 
    return focus.focus()
end 

cli:verb "show" {
    function(args)
        local f = focus_pop_args(args)
        f:each(function(vexid) 
            return print(task:show(vexid)) 
        end)
    end,
    doc = "Prints out a task to terminal, highlighting YAML frontmatter and Markdown notes.",
    args = "[focus]",
    example = "vex show make-coffee"
}

cli:verb "focus" {
    function(args)
        if #args == 0 then 
            local f = focus.read()
            pretty.print('Current focus')
            for _, op in ipairs(f.operations) do
                pretty.print(pretty.string(op.operation, 'cyan'), pretty.string('args = ', 'green'), op.args) 
            end
        else 
            local f = focus.parse(args)
            f:write()
            local vex_cnt = #f:get()
            local ending = " vexes"
            if vex_cnt == 1 then ending = " vex" end 
            pretty.print("Focusing on " .. pretty.string(vex_cnt, "bold") .. ending)
        end 
    end,
    doc = "Creates an focus which can be used as a data query against the vex folder. Provide no args to see the current focus.",
    args = "[focus] [--focusflags...]",
    example = "vex focus all --filter status:done"
}

cli:verb "view" {
    function(args)
        local positional_args = args:positional()

        if #positional_args == 0 then 
            pretty.print('Available views:')
            for view in pairs(view.views) do 
                pretty.print('  ' .. view)
            end 
            return
        end 

        local focusname
        local viewname
        if #positional_args > 1 then 
            focusname = focus_pop_args(positional_args)
            viewname = table.remove(positional_args, 1)
        else 
            viewname = table.remove(positional_args, 1)
            focusname = focus_pop_args(positional_args)
        end
        local flags = args:flags()
        return view:display(viewname, focusname, flags)
    end,
    doc = "Prints a view of current tasks",
    args = "[focus] [view]",
    example = "vex view all table"
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
        taskproperties.description = table.concat(args:positional(), " ")
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
        f:each(function(vexid)
            task:delete(vexid)
            task:remove(vexid)
            pretty.print(vexid)
        end)
        vexdex:setfocus(nil)
        focus.focus('all'):each(function(vexid)
            task:resolve(vexid)
        end)
    end,
    doc = "Deletes tasks in the focus, and drops your focus. Runs resolve on all linked tasks thereafter. Not recommended for regular use.",
    args = "[focus]",
    example = "vex remove make-coffee"
}

cli:verb "get" {
    function(args)
        local f = focus_pop_args(args)
        if #args == 0 then args = {{'vexid'}} end
        f:each(function(vexid)
            pretty.print(task:get(vexid, args))
        end)
    end,
    doc = "Presents the focus in a tangible data format. Can specify which fields by supplying them as flags",
    args = "[focus] [--fields...]",
    example = "vex get all --select due,id,description"
}

cli:verb "set" {
    function(args)
        local f = focus_pop_args(args)
        local taskproperties = args:flags()
        f:each(function(vexid)
            task:set(vexid, taskproperties)
            task:resolve(vexid)
            task:write(vexid)
        end)
    end,
    doc = "Allows you to set fields in the focus. Resolution is called on that `focus`",
    args = "[focus] [--fields...]",
    example = "vex set make-coffee --priority 1"
}

cli:verb "recipe" {
    function(args)
        local recipename = table.remove(args, 1)
        if not recipename then 
            pretty.print('Available recipes:')
            for recipename in pairs(recipe.recipes) do 
                pretty.print('  ' .. recipename)
            end 
            return
        end 

        local taskproperties = args:flags()
        taskproperties.description = table.concat(args:positional(), " ")

        local f = recipe:add(recipename, taskproperties)
        f:each(function(vexid)
            task:write(vexid)
            pretty.print(vexid)
        end)
        f:write()
    end,
    doc = "Creates a recipe (series of tasks). This outputs and changes the focus",
    args = "[recipe] Description... [--fields...]",
    example = "vex recipe abstract Create more vex tasks! --status todo"
}
