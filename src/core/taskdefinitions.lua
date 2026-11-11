local task = require "core.task"
local focus = require 'core.focus'
local vexdex = require 'core.vexdex'
local config = require 'core.config'
local cli = require 'lib.cli'
local func = require 'lib.func'
local pretty = require 'lib.pretty'
local statemachine = require 'lib.statemachine'
local schema = require 'lib.schema'
local event = require 'lib.event'
local naturaltime = require 'lib.naturaltime'
require 'core.schemaext'

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
        modified = schema.default {
            schema.formatted {schema.datetime},
            default = function(self, instance, context) return os.time() end
        },
        vexbody = schema.maybe {schema.str},
        due = schema.default {
            schema.maybe {schema.formatted {schema.datetime}},
            default = function(self, instance, context)
                local dues = func.imap(context.task.dependents, function(vexid)
                    local dependent = vexdex:get(vexid)
                    return dependent.phase ~= 'final' and dependent.due or nil
                end)
                return func.ireduce(dues, function(a, b) return math.min(a, b) end)
            end
        },
        cost = schema.maybe {schema.num},
        benefit = schema.maybe {schema.num},
        owner = schema.maybe {schema.any(config.taskowners)},
        manualtags = schema.maybe {schema.vec {schema.tagoverride}},
        tags = schema.autotagged,
        parent = schema.parent,
        children = schema.unstored {schema.isvalidparent},
        recur = schema.maybe {schema.recurrence},
        over = schema.default {
            schema.maybe {schema.datefield},
            default = function(self, instance, context) return context.task.recur and 'due' or nil end
        },
    }
}

event:register('post-task-resolve', 'recur', function(vexid, t, previous)
    if not (t and t.recur and t.phase == 'final' and previous.vexid and previous.phase ~= 'final') then return end
    local nexttask = func.map(task:getsingle(vexid), function(value)
        return type(value) == "table" and func.map(value, function(v) return v end) or value
    end)
    nexttask.vexid, nexttask.created, nexttask.modified, nexttask.status = nil, nil, nil, nil
    nexttask[t.over] = naturaltime.parse(t.recur, t[t.over] or os.time())
    local successor = task:add(nexttask)
    task:resolve(successor)
end)

task:task 'task':extends 'basetask' {
    schema = schema.atleast {
        status = schema.status,
        dependencies = schema.dependencies
    }
}

task:transient 'wordcount' {
    vextype = 'basetask',
    definition = function(t)
        return select(2, t.description:gsub('%S+', ''))
    end
}

local function tagrules()
    local rules = config.autotags or {}
    if type(rules) ~= "table" then cli:throw('bad-autotags', rules) end
    for name, rule in pairs(rules) do
        if type(name) ~= "string" or not schema.tag:validate(schema.tag:prevalidate(name)) or type(rule) ~= "function" then cli:throw('bad-autotags', name) end
    end
    return rules
end

task:transient 'autotags' {
    vextype = 'basetask',
    definition = function(t)
        local tags = {}
        for name, rule in pairs(tagrules()) do
            local ok, holds = pcall(rule, t)
            if not ok then cli:throw('tag-rule-failed', schema.tag:prevalidate(name), t.vexid, holds) end
            if holds then table.insert(tags, schema.tag:prevalidate(name)) end
        end
        table.sort(tags)
        return #tags > 0 and tags or nil
    end
}

task:transient 'phase' {
    vextype = 'basetask',
    definition = function(t)
        local status = task:schemaof(t.vextype, 'status').specification
        local machine = statemachine.new(status.states, t.status or status.initial, status.initial)
        if machine:isinitial() then return 'initial' end
        if machine:isfinal() then return 'final' end
        return 'interim'
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

task:transient 'dependents' {
    vextype = 'basetask',
    definition = function(t)
        return func.ifilter(t.backlinks, function(vexid)
            local other = vexdex:get(vexid)
            return other and func.any(other.dependencies or {}, function(dependency) return dependency == t.vexid end)
        end)
    end
}

task:transient 'lineage' {
    vextype = 'basetask',
    definition = function(t)
        local ancestors = focus.focus(t.vexid):tree('parent'):get()
        return func.reverse(func.imap(func.slice(ancestors, 2, 'end'), function(ancestor) return ancestor.vexid end))
    end
}

task:transient 'children' {
    vextype = 'basetask',
    definition = function(t)
        local children = func.ifilter(t.backlinks, function(vexid)
            local other = vexdex:get(vexid)
            return other and other.parent == t.vexid
        end)
        return #children > 0 and children or nil
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
        if t.phase == 'final' then return nil end
        local sooner = func.ifilter(focus.focus('all'):get(), function(other)
            return other.owner == t.owner and other.due ~= nil and (t.due == nil or other.due < t.due) and other.phase ~= 'final'
        end)
        return #sooner + 1
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
