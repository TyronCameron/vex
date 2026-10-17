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

local function recording(added)
    return setmetatable({
        add = function(_, taskproperties)
            local vexid = task:add(taskproperties)
            table.insert(added, vexid)
            return vexid
        end
    }, {__index = task})
end

function Recipe:add(name, taskproperties)
    if not self.recipes[name] then cli:throw('unknown-recipe', name) end 
    local added = {}
    self.recipes[name].add(recording(added), taskproperties)
    local f = focus.focus('none')
    for _, vexid in ipairs(added) do
        task:resolve(vexid)
        f = f:union(vexid)
    end
    return f
end

return Recipe.new()
