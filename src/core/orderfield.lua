
local func = require 'lib.func'
local schema = require 'lib.schema'
local vexdex = require 'core.vexdex'

-----------------------------------------------
-- order: an integer field with knowledge of the task manager.
--
-- Not a field in its own right -- many fields on many task types can be
-- declared with it. Options (all optional):
--   ties      bool, default false -- false: setting a value that collides
--             with another task's value bumps that task (and anything it
--             then collides with) up by one, preserving everyone else's
--             relative order. true: duplicate values are left alone.
--   gaps      bool, default true -- false: after resolving ties, the whole
--             partition is compacted to a contiguous range starting at 1.
--   partition string field name, or function(task, context) -> value,
--             scoping which other tasks this task's value competes with.
--             Omitted: every task sharing this field name is one partition.
-----------------------------------------------

local function partitionvalue(spec, task, context)
    if spec.partition == nil then return true end
    if type(spec.partition) == "function" then return spec.partition(task, context) end
    return task[spec.partition]
end

local function fieldname(context)
    return context.path[#context.path]
end

-- every other task (besides the one currently resolving) which has this
-- field set and, if a partition is configured, shares this task's partition
local function siblings(spec, field, context)
    local mine = partitionvalue(spec, context.task, context)
    local found = {}
    for vexid in pairs(vexdex.index) do
        if vexid ~= context.vexid then
            local sibling = context.taskmanager:getsingle(vexid)
            if sibling and sibling[field] ~= nil and partitionvalue(spec, sibling, context) == mine then
                table.insert(found, sibling)
            end
        end
    end
    return found
end

local function persist(context, sibling)
    context.taskmanager:write(sibling.vexid)
end

local function findtied(group, field, value, exclude)
    for _, sibling in ipairs(group) do
        if sibling ~= exclude and sibling[field] == value then return sibling end
    end
    return nil
end

-- domino-bump: whichever sibling ties the current value gets pushed to
-- current + 1, which may then tie the next sibling, and so on. The next
-- collision is looked up (excluding the sibling about to move) before that
-- sibling is actually moved into place, so a sibling never appears to
-- collide with the value it was just given.
local function resolveties(field, context, group, value)
    local current = value
    local tied = findtied(group, field, current)
    while tied do
        local nexttied = findtied(group, field, current + 1, tied)
        tied[field] = current + 1
        persist(context, tied)
        current = current + 1
        tied = nexttied
    end
end

-- compact this task + its partition siblings into a contiguous range,
-- preserving relative order (dense rank, so ties -- if allowed -- share a
-- rank). Returns the (possibly changed) value for the current task.
local function resolvegaps(field, context, group, value)
    local all = {{ task = context.task, value = value, ismine = true }}
    for _, sibling in ipairs(group) do
        table.insert(all, { task = sibling, value = sibling[field] })
    end
    table.sort(all, function(a, b) return a.value < b.value end)

    local myvalue = value
    local rank = 0
    local previous = nil
    for _, entry in ipairs(all) do
        if previous == nil or entry.value ~= previous then
            rank = rank + 1
        end
        previous = entry.value
        if entry.ismine then
            myvalue = rank
        elseif entry.task[field] ~= rank then
            entry.task[field] = rank
            persist(context, entry.task)
        end
    end
    return myvalue
end

schema.register 'order' {
    prevalidate = function(self, instance, context)
        if type(instance) == "string" then
            return tonumber(instance) or instance
        end
        return instance
    end,
    validate = function(self, instance)
        return type(instance) == "number" and instance == math.floor(instance), "The instance: `" .. tostring(instance) .. "` is not an integer"
    end,
    postvalidate = function(self, instance, context)
        local spec = self.specification or {}
        local field = fieldname(context)
        local group = siblings(spec, field, context)

        if spec.ties == false or spec.ties == nil then
            resolveties(field, context, group, instance)
        end

        if spec.gaps == false then
            instance = resolvegaps(field, context, group, instance)
        end

        return instance
    end
}

return schema.order
