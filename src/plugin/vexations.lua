local task = require 'core.task'
local recipe = require 'core.recipe'
local focus = require 'core.focus'
local func = require 'lib.func'
local schema = require 'lib.schema'
require 'core.schemaext'

task:task 'abstract':extends 'basetask' {
    schema = schema.atleast {
        vexbody = schema.maybe {schema.empty},
        options = schema.none,
        dependencies = schema.none,
        children = schema.children
    }
}

task:task 'decision':extends 'basetask' {
    schema = schema.atleast {
        status = schema.status,
        options = schema.vec {
            schema.formatted {schema.vexlink}
        },
        decision = schema.maybe {
            schema.all {
                schema.formatted {schema.vexlink},
                schema.constraint{
                    function(instance, context)
                        return func.any(context.root.options, function(option) return option == instance end), "Decision not found in options"
                    end 
                }
            }
        },
        children = schema.none,
        dependencies = schema.none
    }
}

task:task 'exploration':extends 'basetask' {
    schema = schema.atleast {
        status = schema.status,
        dependencies = schema.dependencies,
        vexbody = schema.empty,
        children = schema.none,
        options = schema.none,
    }
}

task:task 'atom':extends 'basetask' {
    schema = schema.atleast {
        status = schema.status,
        dependencies = schema.dependencies,
        children = schema.none,
        options = schema.none,
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
            local children = add(task, taskproperties)
            task:set(abstract, {children = children})
            return {abstract, unpack(children)}
        end
    }
end

inabstract 'recurring'
inabstract 'repeat'

local function childphases(t)
    local children = rawget(t, 'children')
    if type(children) ~= "table" then children = {children} end
    local indexed = func.ifilter(focus.focus('all'):get(), function(child)
        return func.any(children, function(vexid) return vexid == child.vexid end)
    end)
    return func.imap(indexed, function(child) return child.phase end)
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
