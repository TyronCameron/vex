local task = require "core.task"
local recipe = require 'core.recipe'
local func = require 'lib.func'
local pretty = require 'lib.pretty'
local statemachine = require 'lib.statemachine'
local schema = require 'lib.schema'
local Focus = require 'core.focus'

schema.register 'words' {
    validate = function(self, instance, context)
        if type(instance) ~= "string" then return false end 
        local count = 0
        for _ in instance:gmatch("%S+") do
            count = count + 1
            if count >= self.specification[1] then return true end 
        end
        return false
    end
}

schema.register 'vextype' {
    validate = function(self, instance, context)
        return not not context.taskmanager.tasktypes[instance], "Task type of " .. tostring(instance) .. " does not exist in the taskmanager"
    end
}

schema.register 'statemachine' {
    prevalidate = function(self, instance, context)
        self.extra.statemachine = self.extra.statemachine or statemachine.new(self.specification.states, context.task.status or self.specification.initial)
        return self.extra.statemachine.current 
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
    }
}

task:task 'task' {
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
        status = schema.statemachine {
            states = {
                todo = {
                    valid = {"doing"},
                },
                doing = {
                    valid = {"done"},
                },
                done = {
                    valid = {}
                }
            },
            initial = 'todo'
        },
        vexbody = schema.maybe {schema.str},
        dependencies = schema.maybe {schema.vec {schema.vexlink}},
        due = schema.maybe {schema.formatted {schema.datetime}},
        cost = schema.maybe {schema.num},
        benefit = schema.maybe {schema.num},
    }
}

task:task 'abstract':extends 'task' {
    schema = schema.atleast {
        vexbody = schema.maybe {schema.empty},
        children = schema.default {
            schema.vec {
                schema.formatted {schema.vexlink}
            },
            default = function() return {} end 
        }
    }
}

task:task 'decision':extends 'task' {
    schema = schema.atleast {
        options = schema.vec {
            schema.formatted {schema.vexlink}
        },
        decision = schema.maybe {
            schema.all {
                schema.formatted {schema.vexlink},
                schema.constraint{
                    function(self, instance, context)
                        return func.any(context.root.options, function(option) return option == instance end), "Decision not found in options"
                    end 
                }
            }
        },
        children = schema.maybe {schema.empty}
    }
}

task:task 'exploration':extends 'task' {
    schema = schema.atleast {
        vexbody = schema.empty,
        children = schema.maybe {schema.empty},
    }
}

task:task 'atom':extends 'task' {
    schema = schema.atleast {
        children = schema.maybe {schema.empty},
    }
}

recipe:recipe 'abstract' {
    add = function(task, taskproperties)
        taskproperties.vextype = 'abstract'
        return task:add(taskproperties)
    end
}

-- looks a task up by vexid via a focus (not taskmanager internals), so custom transients
-- never need to dig into TaskManager's caches. Filter, unlike Focus.focus(vexid), doesn't
-- throw for a vexid that isn't indexed yet (e.g. added but not yet resolved)
local function get_task(vexid)
    return Focus.named['all']:filter('vexid', vexid):get()[1]
end

-- counts all tasks transitively reachable via `children`, not just direct children
local function count_descendants(vexid, visited)
    if visited[vexid] then return 0 end
    visited[vexid] = true
    local t = get_task(vexid)
    if not t or type(t.children) ~= "table" then return 0 end
    local count = 0
    for _, childid in ipairs(t.children) do
        count = count + 1 + count_descendants(childid, visited)
    end
    return count
end

task:transient 'descendants' {
    derive = function(t, context)
        return count_descendants(t.vexid, {})
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
