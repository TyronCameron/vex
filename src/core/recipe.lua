local cli = require 'lib.cli'

local Recipe = {}
Recipe.__index = Recipe

-- create new recipe manager
function Recipe.new(task)
    return setmetatable({recipes = {}, taskmanager = task}, Recipe)
end 

function Recipe:recipe(name)
    return function(tab)
        assert(type(tab.add) == "function", "Need to have a function called add to define a recipe")
        self.recipes[name] = tab
    end
end

function Recipe:add(name, taskproperties)
    if not self.recipes[name] then cli:throw('unknown-recipe', name) end 
    return self.recipes[name].add(self.taskmanager, taskproperties)
end

return Recipe
