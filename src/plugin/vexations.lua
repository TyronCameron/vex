local task = require 'core.task'
local recipe = require 'core.recipe'
local vexdex = require 'core.vexdex'
local func = require 'lib.func'
local schema = require 'lib.schema'
local cli = require 'lib.cli'
require 'core.schemaext'

schema.register 'hasnochildren' {
    validate = function(self, children, context)
        if children then cli:throw('has-children', context.vexid, context.task.vextype, children[1]) end
        return true
    end
}

task:task 'abstract':extends 'basetask' {
    schema = schema.atleast {
        vexbody = schema.maybe {schema.empty},
        dependencies = schema.none
    }
}

task:task 'decision':extends 'basetask' {
    schema = schema.atleast {
        status = schema.status,
        decision = schema.maybe {
            schema.all {
                schema.formatted {schema.vexlink},
                schema.constraint{
                    function(instance, context)
                        return func.any(context.task.children or {}, function(option) return option == instance end), "Decision not found in children"
                    end 
                }
            }
        },
        dependencies = schema.none
    }
}

task:task 'exploration':extends 'basetask' {
    schema = schema.atleast {
        status = schema.status,
        dependencies = schema.dependencies,
        vexbody = schema.empty,
        children = schema.unstored {schema.hasnochildren},
    }
}

task:task 'atom':extends 'basetask' {
    schema = schema.atleast {
        status = schema.status,
        dependencies = schema.dependencies,
        children = schema.unstored {schema.hasnochildren},
    }
}

recipe:recipe 'abstract' {
    add = function(task, taskproperties)
        taskproperties.vextype = 'abstract'
        return {task:add(taskproperties)}
    end 
}

local function inabstract(name)
    local add = recipe.recipes[name].add
    recipe:recipe(name) {
        add = function(task, taskproperties)
            local abstract = task:add({description = taskproperties.description, vextype = 'abstract'})
            task:resolve(abstract)
            taskproperties.parent = abstract
            return {abstract, unpack(add(task, taskproperties))}
        end
    }
end

inabstract 'recurring'
inabstract 'repeat'

local function childphases(t)
    return func.imap(t.children or {}, function(vexid) return vexdex:get(vexid).phase end)
end

task:transient 'phase' {
    vextype = 'abstract',
    definition = function(t)
        local phases = childphases(t)
        if func.all(phases, function(phase) return phase == 'initial' end) then return 'initial' end
        if func.all(phases, function(phase) return phase == 'final' end) then return 'final' end
        return 'interim'
    end
}

task:transient 'status' {
    vextype = 'abstract',
    definition = function(t)
        return ({initial = 'todo', interim = 'doing', final = 'done'})[t.phase]
    end
}

return {}
