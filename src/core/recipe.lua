local cli = require 'lib.cli'
local task = require 'core.task'
local focus = require 'core.focus'
local event = require 'lib.event'
local func = require 'lib.func'

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
    event:trigger('pre-recipe-add', name, taskproperties)
    local vexids = self.recipes[name].add(task, taskproperties)
    for _, vexid in ipairs(vexids) do
        task:resolve(vexid)
    end
    local f = focus.focus(vexids)
    event:trigger('post-recipe-add', name, f)
    return f
end

local recipes = Recipe.new()

recipes:recipe 'recurring' {
    add = function(task, taskproperties)
        if not taskproperties.recur then cli:throw('recipe-needs-flag', 'recurring', 'recur', 'how often the task recurs, such as `weekly` or `3 days`') end
        if taskproperties.start then taskproperties[taskproperties.over or 'due'] = taskproperties.start end
        taskproperties.start = nil
        return {task:add(taskproperties)}
    end
}

recipes:recipe 'repeat' {
    add = function(task, taskproperties)
        local n = tonumber(taskproperties.n)
        if not n or n < 1 or n % 1 ~= 0 then cli:throw('recipe-needs-flag', 'repeat', 'n', 'how many tasks to add, a whole number above 0') end
        taskproperties.n = nil
        local vexids = {}
        for _ = 1, n do
            local vexid = task:add(func.map(taskproperties, function(v) return v end))
            task:resolve(vexid)
            table.insert(vexids, vexid)
        end
        return vexids
    end
}

return recipes
