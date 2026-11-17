local task = require 'core.task'
local recipe = require 'core.recipe'
local vexdex = require 'core.vexdex'
local func = require 'lib.func'
local schema = require 'lib.schema'
local cli = require 'lib.cli'
require 'core.schemaext'

schema.register 'dependable' {
    validate = function(self, dependency, context)
        local vextype = task:getsingle(dependency).vextype
        if vextype == 'abstract' or vextype == 'decision' then cli:throw('undependable', context.vexid, dependency, vextype) end
        return true
    end
}

local dependencies = schema.all {schema.dependencies, schema.maybe {schema.vec {schema.dependable}}}

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
        dependencies = dependencies,
        vexbody = schema.empty,
        children = schema.none,
    }
}

task:task 'atom':extends 'basetask' {
    schema = schema.atleast {
        status = schema.status,
        dependencies = dependencies,
        children = schema.none,
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
