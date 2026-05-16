local VexDex = require "core.vexdex"
local Task = require "core.task"
local focus = require 'core.focus'
local cfg = require 'lib.config'
local recipe = require 'core.recipe'

local func = require 'lib.func'
local pretty = require 'lib.pretty'

local function bootstrap()
    local vexdex = VexDex.new()
    local config = cfg.new():registerpath(vexdex:vexpath('config.lua')):loadall()
    focus.init(vexdex)
    local task = Task.new(vexdex, config)
    local recipe = recipe.new(task)

    recipe:recipe 'abstract' {
        add = function(task, taskproperties)
            taskproperties.vextype = 'abstract'
            taskproperties.vexbody = nil
            taskproperties.status = nil
            task:add(taskproperties)
        end
    }

    return task, vexdex, config, recipe
end 

return bootstrap