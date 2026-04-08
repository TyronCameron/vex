local cli = require "lib.cli"
local VexDex = require "core.vexdex"
local Task = require "core.task"
local optic = require 'core.optic'
local cfg = require 'lib.config'
local func = require 'lib.func'

local function bootstrap()
    local vexdex = VexDex.new()
    local config = cfg.new():registerpath(vexdex:vexpath('config.lua')):loadall()
    return Task.new(vexdex, config)
end 

local function args_to_single_table(args)
    local taskproperties = {}
    local argproperties = func.ifilter(args, function(word) return type(word) == "table" end)
    for _, pair in ipairs(argproperties) do
        if taskproperties[pair[2]] then 
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
        local opt = optic:get(args[1])
        Task:show(opt)
    end,
    doc = "Prints out a task to terminal, highlighting YAML frontmatter and Markdown notes.",
    args = "[optic]",
    example = "vex show make-coffee"
}

cli:verb "optic" {
    function(args)
        cli:throw("unimplemented")
    end,
    doc = "Creates an optic which can be used as a data query against the vex folder",
    args = "[optic] [flags...]",
    example = "vex optic all --filter status:done"
}


cli:verb "view" {
    function(args)
        cli:throw("unimplemented")
    end,
    doc = "Prints a view of current tasks",
    args = "[optic] [view] [flags...]",
    example = "vex view all table"
}

cli:verb "resolve" {
    function(args)
        cli:throw("unimplemented")
    end,
    doc = "Validates, updates and normalises fields and tasks",
    args = "[optic]",
    example = "vex resolve all"
}

cli:verb "add" {
    function(args)
        local task = bootstrap()

        local taskproperties = args_to_single_table(args)
        taskproperties.description = table.concat(positional_args(args), " ")

        local vexid = task:add(taskproperties)
        task:resolve(vexid)
        task:write(vexid)
        return vexid
    end,
    doc = "Creates a task with the Description provided. Automatically fills out some frontmatter and resolves. This outputs and sets the optic to this new tag",
    args = "Description [flags...]",
    example = "vex add Make coffee for wife --importance high"
}

cli:verb "remove" {
    function(args)
        local task = bootstrap()

        local vexid = task:delete(args[1])
        task:remove()
        task:resolve(vexid)
        return vexid
    end,
    doc = "Deletes tasks in the optic. Runs resolve on all linked tasks thereafter. Not recommended for regular use",
    args = "[optic]",
    example = "vex remove make-coffee"
}

cli:verb "get" {
    function(args)
        cli:throw("unimplemented")
    end,
    doc = "Presents the optic in a tangible data format. Can specify which fields by supplying them as flags",
    args = "[optic] [flags...]",
    example = "vex get all --select due,id,description"
}

cli:verb "set" {
    function(args)
        cli:throw("unimplemented")
    end,
    doc = "Allows you to set fields in the optic. Resolution is called on that `optic`",
    args = "[optic] [flags...]",
    example = "vex set make-coffee --priority 1"
}

cli:verb "recipe" {
    function(args)
        cli:throw("unimplemented")
    end,
    doc = "Creates a recipe (series of tasks). This outputs and changes the optic",
    args = "recipe",
    example = "vex recipe abstract"
}