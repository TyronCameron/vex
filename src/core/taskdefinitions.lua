local task = require "core.task"
local recipe = require 'core.recipe'
local func = require 'lib.func'
local pretty = require 'lib.pretty'
local statemachine = require 'lib.statemachine'
local schema = require 'lib.schema'

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
        children = schema.vec {
            schema.formatted {schema.vexlink}
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
