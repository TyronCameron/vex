local task = require "core.task"
local recipe = require 'core.recipe'
local focus = require 'core.focus'
local vexdex = require 'core.vexdex'
local config = require 'core.config'
local cli = require 'lib.cli'
local func = require 'lib.func'
local pretty = require 'lib.pretty'
local statemachine = require 'lib.statemachine'
local schema = require 'lib.schema'

schema.register 'words' {
    validate = function(self, instance, context)
        local count = 0
        for _ in tostring(type(instance) == "string" and instance or ""):gmatch("%S+") do
            count = count + 1
            if count >= self.specification[1] then return true end 
        end
        return false, "Expected at least " .. self.specification[1] .. " words"
    end
}

schema.register 'vextype' {
    validate = function(self, instance, context)
        return not not context.taskmanager.tasktypes[instance], "Task type of " .. tostring(instance) .. " does not exist in the taskmanager"
    end
}

schema.register 'statemachine' {
    prevalidate = function(self, instance, context)
        local previous = context.previous
        for _, key in ipairs(context.path) do previous = previous and previous[key] end
        self.extra.statemachine = statemachine.new(self.specification.states, previous, self.specification.initial)
        return instance or self.specification.initial
    end,
    validate = function(self, instance, context)
        return self.extra.statemachine:isvalid(instance), "Cannot transition status from " .. tostring(self.extra.statemachine.current) .. " to " .. tostring(instance)
    end,
    postvalidate = function(self, instance, context)
        self.extra.statemachine:transition(instance)
        return instance
    end
}

schema.register 'vexlink' {
    validate = function(self, vexid)
        return type(vexid) == "string" and task:getsingle(vexid), "Cannot find " .. tostring(vexid) .. " in the task manager "
    end,
    isos = {
        format = {
            backward = function(self, vexlink)
                return vexlink:match("%[%[(.-)%]%]") or vexlink
            end,
            forward = function(self, vexid)
                return "[[" .. vexid .. "]]"
            end,
        }
    },
    postvalidate = function(self, vexid, context)
        table.insert(context.links, vexid)
        return vexid
    end
}

local function singleparent(child, context)
    for _, parent in ipairs(focus.getalltasks()) do
        if parent.vexid ~= context.vexid and type(parent.children) == "table" then
            for _, other in ipairs(parent.children) do
                if other == child then cli:throw('multiple-parents', child, context.vexid, parent.vexid) end
            end
        end
    end
    return true
end

local function notself(child, context)
    if child == context.vexid then cli:throw('self-child', child) end
    return true
end

local function acyclic(dependency, context)
    for _, reachable in ipairs(focus.focus(dependency):tree('dependencies'):get()) do
        if reachable.vexid == context.vexid then cli:throw('dependency-cycle', context.vexid, dependency) end
    end
    return true
end

local function holds(task, field)
    return type(task[field]) == "table" and #task[field] > 0
end

local function childless(dependency, context)
    local target = focus.focus(dependency):get()[1]
    if holds(target, 'children') or holds(target, 'options') then
        cli:throw('dependency-with-children', context.vexid, dependency)
    end
    return true
end

local function status()
    return schema.statemachine {
        states = {
            todo = {
                valid = {"done"},
            },
            done = {
                valid = {}
            }
        },
        initial = 'todo'
    }
end

local function dependencies()
    return schema.maybe {
        schema.unique {
            schema.all {
                schema.formatted {schema.vexlink},
                schema.constraint {acyclic},
                schema.constraint {childless}
            }
        }
    }
end

task:task 'basetask' {
    schema = schema.atleast {
        vexid = schema.all(schema.str, schema.size {3}),
        description = schema.all {
            schema.str, 
            schema.size {3},
            schema.words {2}
        },
        vextype = schema.default {schema.vextype, function() return 'task' end},
        created = schema.default {
            schema.formatted {schema.datetime},
            default = function(self, instance, context) return os.time() end
        },
        modified = schema.derive {
            schema.formatted {schema.datetime},
            derive = function(self, instance, context) return os.time() end
        },
        vexbody = schema.maybe {schema.str},
        due = schema.maybe {schema.formatted {schema.datetime}},
        cost = schema.maybe {schema.num},
        benefit = schema.maybe {schema.num},
        owner = schema.maybe {schema.any(config.taskowners)},
    }
}

task:task 'task':extends 'basetask' {
    schema = schema.atleast {
        status = status(),
        dependencies = dependencies()
    }
}

task:task 'abstract':extends 'basetask' {
    schema = schema.atleast {
        vexbody = schema.maybe {schema.empty},
        options = schema['nil'],
        dependencies = schema['nil'],
        children = schema.default {
            schema.unique {
                schema.all {
                    schema.formatted {schema.vexlink},
                    schema.constraint {notself},
                    schema.constraint {singleparent}
                }
            },
            default = function() return {} end 
        }
    }
}

task:task 'decision':extends 'basetask' {
    schema = schema.atleast {
        status = status(),
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
        children = schema['nil'],
        dependencies = schema['nil']
    }
}

task:task 'exploration':extends 'basetask' {
    schema = schema.atleast {
        status = status(),
        dependencies = dependencies(),
        vexbody = schema.empty,
        children = schema['nil'],
        options = schema['nil'],
    }
}

task:task 'atom':extends 'basetask' {
    schema = schema.atleast {
        status = status(),
        dependencies = dependencies(),
        children = schema['nil'],
        options = schema['nil'],
    }
}

recipe:recipe 'abstract' {
    add = function(task, taskproperties)
        taskproperties.vextype = 'abstract'
        return {task:add(taskproperties)}
    end 
}

task:transient 'wordcount' {
    vextype = 'basetask',
    definition = function(t)
        return select(2, t.description:gsub('%S+', ''))
    end
}

task:transient 'phase' {
    vextype = 'basetask',
    definition = function(t)
        local status = task:schemaof(t.vextype, 'status').specification
        local machine = statemachine.new(status.states, t.status, status.initial)
        if machine:isinitial() then return 'initial' end
        if machine:isfinal() then return 'final' end
        return 'interim'
    end
}

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

task:transient 'blockers' {
    vextype = 'basetask',
    definition = function(t)
        if not t.dependencies or #t.dependencies == 0 then return {} end
        local unfinished = {}
        for _, dependency in ipairs(focus.focus(t.dependencies):intersect(focus.focus('final'):complement()):get()) do
            unfinished[dependency.vexid] = true
        end
        return func.ifilter(t.dependencies, function(vexid) return unfinished[vexid] end)
    end
}

task:transient 'lineage' {
    vextype = 'basetask',
    definition = function(t)
        local ancestors = focus.focus(t.vexid):reversetree('children', 'options'):get()
        return func.reverse(func.imap(func.slice(ancestors, 2, 'end'), function(ancestor) return ancestor.vexid end))
    end
}

task:transient 'parent' {
    vextype = 'basetask',
    definition = function(t)
        local ancestors = focus.focus(t.vexid):reversetree('children', 'options'):get()
        return ancestors[2] and ancestors[2].vexid
    end
}

task:transient 'backlinks' {
    vextype = 'basetask',
    definition = function(t)
        return vexdex:linksto(t.vexid)
    end
}

task:transient 'forwardlinks' {
    vextype = 'basetask',
    definition = function(t)
        return task:forwardlinks(t)
    end
}

task:transient 'path' {
    vextype = 'basetask',
    definition = function(t)
        return task:getcurrentpath(t.vexid)
    end
}

task:transient 'age' {
    vextype = 'basetask',
    definition = function(t)
        return t.created and math.floor((os.time() - t.created) / 86400)
    end
}

task:transient 'urgency' {
    vextype = 'basetask',
    definition = function(t)
        local ranked = focus.focus('final'):complement():groupby('owner'):orderby('due'):rn():filter('vexid', t.vexid):get()[1]
        return ranked and ranked.rn
    end
}

-- task:field 'due' {
--     normalise = function(value, context)
--         if type(value) == "number" then return math.floor(value) end
--         if type(value) == "string" then return parse_datetime(value) end
--         return nil
--     end,
--     validate = function(value, context)
--         return type(value) == "number" 
--         and os.time() + (1000 * 365 * 24 * 3600) < value 
--         and value < 46684800
--     end,
--     format = function(value, context)
--         return format_datetime(value)
--     end
-- }

-- local exploration_status = {
--     unexplored = {
--         valid = {"explored"},
--     },
--     explored = {
--         valid = {}
--     }
-- }

-- task:field 'exploration_status' {
--     normalise = function(value, context)
--         return value and statemachine.new(statuses, context.task.status)
--     end,
--     validate = function(value, context)
--         return statuses[context.task.status.current]
--     end,
--     derive = function(context)
--         return statemachine.new(statuses, context.task.status or 'todo')
--     end
-- }
