local cli = require 'lib.cli'
local task = require 'core.task'
local focus = require 'core.focus'

local Recipe = {}
Recipe.__index = Recipe

-- create new recipe manager
function Recipe.new()
    return setmetatable({recipes = {}}, Recipe)
end 

function Recipe:recipe(name)
    return function(tab)
        assert(type(tab.add) == "function", "Need to have a function called add to define a recipe")
        self.recipes[name] = tab
    end
end

function Recipe:add(name, taskproperties)
    if not self.recipes[name] then cli:throw('unknown-recipe', name) end 
    local vexid = self.recipes[name].add(task, taskproperties)
    task:resolve(vexid)
    return focus.focus(vexid)
end

return Recipe.new()
