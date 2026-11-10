local cli = require 'lib.cli'
local func = require 'lib.func'
local statemachine = require 'lib.statemachine'
local schema = require 'lib.schema'
local naturaltime = require 'lib.naturaltime'
local vexdex = require 'core.vexdex'
local task = require 'core.task'
local focus = require 'core.focus'

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

local tagpattern = '^#[^%s#]+$'

local function unsigned(override)
    return (override:gsub('^%-', '', 1))
end

schema.register 'tag' {
    prevalidate = function(self, instance)
        return type(instance) == "string" and (instance:gsub('^#?', '#', 1)) or instance
    end,
    validate = function(self, instance)
        return type(instance) == "string" and instance:match(tagpattern) ~= nil, "Expected a tag, a # and then a word without spaces, got `" .. tostring(instance) .. "`"
    end
}

schema.register 'tagoverride' {
    prevalidate = function(self, instance)
        if type(instance) ~= "string" then return instance end
        local sign, word = instance:match('^([+-]?)(.*)$')
        return (sign == '-' and '-' or '') .. schema.tag:prevalidate(word)
    end,
    validate = function(self, instance)
        return type(instance) == "string" and unsigned(instance):match(tagpattern) ~= nil, "Expected a tag, a # and then a word without spaces, with a - in front to suppress it, got `" .. tostring(instance) .. "`"
    end
}

local taglist = schema.maybe {schema.vec {schema.tag}}

schema.register 'autotagged' {
    prevalidate = function(self, instance)
        return taglist:prevalidate(instance)
    end,
    validate = function(self, instance)
        return taglist:validate(instance)
    end,
    postvalidate = function(self, instance, context)
        local manual = context.root.manualtags or {}
        local wanted = {}
        for _, tag in ipairs(context.root.autotags or {}) do wanted[tag] = true end
        for _, override in ipairs(manual) do
            if override:sub(1, 1) ~= '-' then wanted[override] = true end
        end
        for _, override in ipairs(manual) do
            if override:sub(1, 1) == '-' then wanted[unsigned(override)] = nil end
        end
        local tags = func.sortedkeys(wanted)
        return #tags > 0 and tags or nil
    end
}

schema.register 'acyclic' {
    validate = function(self, target, context)
        local field, errorname = self.specification[1], self.specification[2]
        for _, reachable in ipairs(focus.focus(target):tree(field):get()) do
            if reachable.vexid == context.vexid then cli:throw(errorname, context.vexid, target) end
        end
        return true
    end
}

schema.register 'childless' {
    validate = function(self, dependency, context)
        local target = focus.focus(dependency):get()[1]
        if #(target.children or {}) > 0 then
            cli:throw('dependency-with-children', context.vexid, dependency)
        end
        return true
    end
}

schema.register 'hasvalidparent' {
    validate = function(self, parent, context)
        local target = task:getsingle(parent)
        if target.leaf then cli:throw('leaf-parent', context.vexid, parent, target.vextype) end
        local dependents = target.dependents
        if #dependents > 0 then cli:throw('depended-parent', context.vexid, parent, dependents[1]) end
        return true
    end
}

schema.register 'dueinorder' {
    validate = function(self, dependency, context)
        local needed = vexdex:get(dependency)
        if needed.due and context.task.due and needed.due > context.task.due and needed.phase ~= 'final' and context.task.phase ~= 'final' then
            cli:throw('due-out-of-order', context.vexid, dependency)
        end
        return true
    end
}

schema.register 'recurrence' {
    validate = function(self, phrase)
        local now = os.time()
        local ok, after = pcall(naturaltime.parse, tostring(phrase), now)
        return type(phrase) == "string" and ok and after > now, "Expected a recurrence such as `weekly`, `monthly` or `3 days`, got `" .. tostring(phrase) .. "`"
    end
}

schema.register 'datefield' {
    validate = function(self, field, context)
        local fieldschema = type(field) == "string" and context.taskmanager:schemaof(context.task.vextype, field)
        return fieldschema and #fieldschema:collect('datetime', 0) + #fieldschema:collect('date', 0) > 0, "Expected the name of a date field to recur over, such as `due`, got `" .. tostring(field) .. "`"
    end
}

schema.register 'status' (schema.statemachine {
    states = {
        todo = {
            valid = {"done"},
        },
        done = {
            valid = {}
        }
    },
    initial = 'todo'
})

schema.register 'dependencies' (schema.maybe {
    schema.unique {
        schema.all {
            schema.formatted {schema.vexlink},
            schema.acyclic {'dependencies', 'dependency-cycle'},
            schema.childless,
            schema.dueinorder
        }
    }
})

schema.register 'parent' (schema.maybe {
    schema.all {
        schema.formatted {schema.vexlink},
        schema.acyclic {'parent', 'parent-cycle'},
        schema.hasvalidparent
    }
})
