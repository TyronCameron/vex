local cli = require "lib.cli"
local VexDex = require "core.vexdex"
local Task = require "core.task"
local focus = require 'core.focus'
local cfg = require 'lib.config'
local func = require 'lib.func'
local pretty = require 'lib.pretty'

local function bootstrap()
    local vexdex = VexDex.new()
    local config = cfg.new():registerpath(vexdex:vexpath('config.lua')):loadall()
    return Task.new(vexdex, config)
end 

local function argflags(args)
    local taskproperties = {}
    local argproperties = func.ifilter(args, function(word) return type(word) == "table" end)
    for _, pair in ipairs(argproperties) do
        if pair[2] then 
            taskproperties[pair[1]] = pair[2]
        end 
    end
    return taskproperties
end 

local function positional_args(args)
    return func.ifilter(args, function(word) return type(word) == "string" end)
end 

cli:verb "init" {
    function(args)
        VexDex.init()
    end,
    doc = "Initialise a new vex directory by setting up a `.vex` folder",
    args = "",
    example = "vex init"
}

cli:verb "show" {
    function(args)
        local task = bootstrap()
        task:show(args[1])
    end,
    doc = "Prints out a task to terminal, highlighting YAML frontmatter and Markdown notes.",
    args = "[focus]",
    example = "vex show make-coffee"
}

cli:verb "focus" {
    function(args)
        local vexdex = VexDex.new()
        focus.init(vexdex)
        local f = focus.parse(args)
        vexdex:setfocus(f)
    end,
    doc = "Creates an focus which can be used as a data query against the vex folder",
    args = "[focus] [flags...]",
    example = "vex focus all --filter status:done"
}

cli:verb "view" {
    function(args)
        cli:throw("unimplemented")
    end,
    doc = "Prints a view of current tasks",
    args = "[focus] [view] [flags...]",
    example = "vex view all table"
}

cli:verb "resolve" {
    function(args)
        local task = bootstrap()
        task:resolve(args[1])
    end,
    doc = "Validates, updates and normalises fields and tasks",
    args = "[focus]",
    example = "vex resolve all"
}

cli:verb "add" {
    function(args)
        local task = bootstrap()

        local taskproperties = argflags(args)
        taskproperties.description = table.concat(positional_args(args), " ")

        local vexid = task:add(taskproperties)
        task:resolve(vexid)
        task:write(vexid)
        return vexid
    end,
    doc = "Creates a task with the Description provided. Automatically fills out some frontmatter and resolves. This outputs and sets the focus to this new tag",
    args = "Description [flags...]",
    example = "vex add Make coffee for wife --importance high"
}

cli:verb "remove" {
    function(args)
        local task = bootstrap()
        local vexid = task:delete(args[1])
        task:remove(vexid)
        task:resolve(vexid)
    end,
    doc = "Deletes tasks in the focus. Runs resolve on all linked tasks thereafter. Not recommended for regular use",
    args = "[focus]",
    example = "vex remove make-coffee"
}

cli:verb "get" {
    function(args)
        local task = bootstrap()
        return task:getstring(args[1])
    end,
    doc = "Presents the focus in a tangible data format. Can specify which fields by supplying them as flags",
    args = "[focus] [flags...]",
    example = "vex get all --select due,id,description"
}

cli:verb "set" {
    function(args)
        local task = bootstrap()
        local vexid = positional_args(args)[1]
        local taskproperties = argflags(args)
        task:set(vexid, taskproperties)
        task:resolve(vexid)
        task:write(vexid)
    end,
    doc = "Allows you to set fields in the focus. Resolution is called on that `focus`",
    args = "[focus] [flags...]",
    example = "vex set make-coffee --priority 1"
}

cli:verb "recipe" {
    function(args)
        cli:throw("unimplemented")
    end,
    doc = "Creates a recipe (series of tasks). This outputs and changes the focus",
    args = "recipe",
    example = "vex recipe abstract"
}