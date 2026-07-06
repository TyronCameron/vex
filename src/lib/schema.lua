
local func = require 'lib.func'
local pretty = require "lib.pretty"

-----------------------------------------------
-- Context
-----------------------------------------------

local Context = {}
Context.__index = Context

function Context.new(schema, value, context)
    if getmetatable(context) == Context then return context end
    local this = {
        path = {},
        types = {schema._name},
        rootschema = schema,
        root = value,
        currentvalue = value,
        currentschema = schema
    }
    if type(context) == "table" then 
        for key, value in pairs(context) do
            this[key] = this[key] or value
        end
    end 
    return setmetatable(this, Context)
end 

function Context:snapshot()
    return setmetatable({
        path = func.imap(self.path, function(x) return x end),
        types = func.imap(self.types, function(x) return x end),
        rootschema = self.rootschema,
        root = self.root,
        currentvalue = self.currentvalue,
        currentschema = self.currentschema,
    }, Context)
end

function Context:descend(schemakey, instancekey, fn)
    local parentschema = self.currentschema
    local parentvalue = self.currentvalue

    if schemakey ~= nil then
        self.currentschema = self.currentschema.specification[schemakey]
        table.insert(self.types, self.currentschema._name)
    end
    if instancekey ~= nil then
        table.insert(self.path, instancekey)
        self.currentvalue = self.currentvalue[instancekey]
    end

    local value = fn()

    if instancekey ~= nil then
        self.currentvalue = parentvalue
        table.remove(self.path)
    end
    if schemakey ~= nil then
        table.remove(self.types)
        self.currentschema = parentschema
    end

    return value
end

function Context:tostring(content)
    local path = table.concat(self.path or {}, ".")
    local types = table.concat(self.types or {}, ".")
    return table.concat({
        content and ("\t" .. tostring(content)) or "",
        "Context:",
        "\tPath: `" .. path .. "`",
        "\tSchema types: `" .. types .. "`",
        "\tSchema: `" .. tostring(self.currentschema or 'unknown') .. "`",
        "\tInstance: `" .. pretty.any(self.currentvalue or 'unknown') .. "`",
    }, "\n")
end

-----------------------------------------------
-- Schema
-----------------------------------------------

local templates = {} 

local Schema = {} 
Schema.__index = Schema
Schema.__call = function(self, ...)
    local specification = select('#', ...) > 1 and {...} or ...
    local complete_schema = setmetatable({}, Schema)
    for k, v in pairs(self) do complete_schema[k] = v end
    complete_schema.specification = specification
    return complete_schema
end
Schema.__tostring = function(self)
    return tostring(self._name)
end
setmetatable(Schema, {
    __index = function(_, key)
        return templates[key] and Schema.instantiate(key)
    end
})
-- at register time, I have a definition 
-- at instantiation time, I have a specification 
-- at validation time, I have an instance 

function Schema.new(definition)
    assert(type(definition) == "table", "Need to pass in a table for a new schema definition")
    assert(type(definition.validate) == "function", "Must pass in a validation function for a schema")
    return setmetatable({
        _prevalidate = definition.prevalidate,
        _validate = definition.validate,
        _postvalidate = definition.postvalidate,
        _iterate = definition.iterate,
        _isos = definition.isos,
        _error = definition.error,
        _name = definition.name or 'schema',
        extra = definition.extra or {} 
    }, Schema)
end

function Schema.register(name)
    assert(type(name) == "string", "Attempting to register a schema without a string name.")
    return function(definition)
        definition.name = definition.name or name 
        templates[name] = Schema.new(definition)
    end 
end

function Schema.instantiate(name, specification)
    if templates[name] then -- create a template with or without specification  
        return templates[name](specification)
    elseif name and getmetatable(name) == Schema then -- already a schema 
        return name
    elseif name and not specification then -- constant value 
        return templates['constant'](name)
    end 
    assert(false, 'Badly called schema instantiation')
end

-----------------------------------------------
-- API
-----------------------------------------------

function Schema:error(value, context, msg)
    local err_msg = self._error and self._error(self, value, context) or ""
    local error_message = {context:tostring(msg)}
    if err_msg then table.insert(error_message, tostring(err_msg)) end 
    assert(false, table.concat(error_message, ". "))
end

function Schema:prevalidate(value, context)
    context = Context.new(self, value, context)
    local snap = context:snapshot()
    if not self._prevalidate then return value end 
    local ok, res = pcall(self._prevalidate, self, value, context)
    if not ok then self:error(value, snap, "Prevalidation step errored:\n" .. tostring(res)) end 
    return res 
end

function Schema:validate(value, context)
    context = Context.new(self, value, context)
    local snap = context:snapshot()
    local ok, res, err = pcall(self._validate, self, value, context)
    if not ok then self:error(value, snap, "Validation step errored:\n" .. tostring(res)) end 
    if res then return true end 
    local errmsg = "Validation failed:\n" .. (err and tostring(err) or '') .. "\n" .. snap:tostring()
    return res, errmsg
end

function Schema:postvalidate(value, context)
    context = Context.new(self, value, context)
    local snap = context:snapshot()
    if not self._postvalidate then return value end 
    local ok, res = pcall(self._postvalidate, self, value, context)
    if not ok then self:error(value, snap, "Postvalidation step errored:\n" .. tostring(res)) end 
    return res 
end

function Schema:findiso(isoname, instance, context)
    if self._isos and self._isos[isoname] then
        return self, self._isos[isoname]
    end
    if self._iterate then 
        for lowerschema in self:iterate(instance, context) do
            local found_schema, found_iso = lowerschema:findiso(isoname)
            if found_iso then return found_schema, found_iso end
        end
    end 
    return nil, nil
end

function Schema:apply(isoname, value, context)
    context = Context.new(self, value, context)
    local owner, iso = self:findiso(isoname)
    assert(iso, "No iso of name " .. tostring(isoname) .. " found.")
    local ok, res = pcall(iso.forward, owner, value, context)
    if not ok then self:error(value, context, "Iso failed forward transformation: " .. tostring(res)) end
    return res
end

function Schema:unapply(isoname, value, context)
    context = Context.new(self, value, context)
    local owner, iso = self:findiso(isoname)
    assert(iso, "No iso of name " .. tostring(isoname) .. " found.")
    local ok, res = pcall(iso.backward, owner, value, context)
    if not ok then self:error(value, context, "Iso failed backward transformation: " .. tostring(res)) end
    return res
end

function Schema:get(data, path, isoname, context)
    local current_schema = self
    local current_value = data
    context = Context.new(self, data, context)

    for _, key in ipairs(path) do
        local found = false
        for schema, instance, schemakey, instancekey in current_schema:iterate(current_value, context) do
            if key == instancekey then
                current_schema = schema
                current_value = instance
                found = true
                break
            end
        end
        if not found then return nil end
    end

    if isoname then 
        current_value = current_schema:apply(isoname, current_value, context)
    end 

    return current_value, current_schema
end

function Schema:set(data, path, isoname, context)
    local pathcopy = {}
    context = Context.new(self, data, context)
    for _,v in ipairs(path) do table.insert(pathcopy, v) end
    local laststep = {table.remove(pathcopy)}
    local penult_value, penult_schema = self:get(data, pathcopy, nil, context)
    assert(penult_schema, "Invalid path -- cannot find penult schema!")
    local ult_value, ult_schema = penult_schema:get(penult_value, laststep, nil, context)
    assert(ult_schema, "Invalid path -- cannot find nult schema!")
    penult_value[laststep[1]] = ult_schema:unapply(isoname, ult_value)
    return self 
end

function Schema:iterate(instance, context)
    context = Context.new(self, instance, context)
    return coroutine.wrap(function()
        for schemakey, instancekey in self._iterate(self, instance, context) do
            if self.specification[schemakey] then 
                local childschema = Schema.instantiate(self.specification[schemakey])
                self.specification[schemakey] = childschema
                context:descend(schemakey, instancekey, function()
                    if instancekey ~= nil then
                        coroutine.yield(childschema, instance[instancekey], schemakey, instancekey)
                    else
                        coroutine.yield(childschema, instance, schemakey, instancekey)
                    end
                end)
            end 
        end
    end)
end

-----------------------------------------------
-- Core types
-----------------------------------------------

-- checks that the function provided validates the instance 
Schema.register 'constraint' {
    validate = function(self, instance, context)
        if type(self.specification) == "function" then return self.specification(instance, context) end 
        if type(self.specification.validate) == "function" then return self.specification.validate(instance, context) end 
        if type(self.specification[1]) == "function" then return self.specification[1](instance, context) end 
        assert(false, "Constraint schema set up wrong. Don't know how to handle the constraint")
    end
}

-- checks for a single constant value 
Schema.register 'constant' {
    validate = function(self, instance)
        return self.specification == instance, "The instance: `" .. tostring(instance) .. "` is not a the exact constant `" .. tostring(self.specification) .. '`'
    end
}

-----------------------------------------------
-- Container schemas
-----------------------------------------------
---
local function prevalidate_children(self, instance, context)
    if type(instance) == "table" then 
        for childschema, childinstance, schemakey, instancekey in self:iterate(instance, context) do 
            if instancekey ~= nil then 
                instance[instancekey] = childschema:prevalidate(childinstance, context) 
            end 
        end 
    end 
    return instance
end 

local function validate_children(self, instance, context)
    if instance == nil then return false, "Found nil instance when expecting to iterate through subschemas" end 
    for childschema, childinstance in self:iterate(instance, context) do 
        local valid, err = childschema:validate(childinstance, context)
        if not valid then return false, err end 
    end 
    return true 
end 

local function postvalidate_children(self, instance, context)
    if type(instance) == "table" then 
        for childschema, childinstance, schemakey, instancekey in self:iterate(instance, context) do 
            if instancekey ~= nil then 
                instance[instancekey] = childschema:postvalidate(childinstance, context) 
            end 
        end 
    end
    return instance
end 

-- checks that a table matches the schema given 
Schema.register 'exactly' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            local done = {}
            for key in pairs(instance) do
                done[key] = true
                coroutine.yield(key, key)
            end
            for key in pairs(self.specification) do
                if not done[key] then 
                    coroutine.yield(key, key)
                end 
            end 
        end)
    end,
    prevalidate = prevalidate_children,
    validate = function(self, instance, context)
        if instance == nil then return false end
        for key in pairs(instance) do
            if self.specification[key] == nil then 
                return false, "Key `" .. tostring(key) .. "` found in instance but not in schema."
            end
        end
        for key in pairs(self.specification) do
            if instance[key] == nil then 
                return false, "Key `" .. tostring(key) .. "` found in schema but not in instance."
            end
        end
        return validate_children(self, instance, context)
    end,
    postvalidate = postvalidate_children
}

-- checks that a table has at most the keys specified 
Schema.register 'atmost' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            for key in pairs(instance) do
                coroutine.yield(key, key)
            end
        end)
    end,
    prevalidate = prevalidate_children,
    validate = function(self, instance, context)
        if instance == nil then return false end
        for key in pairs(instance) do
            if self.specification[key] == nil then 
                return false, "Key `" .. tostring(key) .. "` found in instance but not in schema."
            end
        end
        return validate_children(self, instance, context)
    end,
    postvalidate = postvalidate_children
}

-- checks that a table has at least the keys specified 
Schema.register 'atleast' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            for key in pairs(self.specification) do
                coroutine.yield(key, key)
            end
        end)
    end,
    prevalidate = prevalidate_children,
    validate = validate_children,
    postvalidate = postvalidate_children
}

-- checks for existence as well as any of the listed options
Schema.register 'any' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            for key in ipairs(self.specification) do
                coroutine.yield(key, nil)
            end
        end)
    end,
    validate = function(self, instance, context) 
        if self.specification == nil or func.isempty(self.specification) then return true end
        for childschema, childinstance in self:iterate(instance, context) do 
            if childschema:validate(childinstance, context) then return true end 
        end 
        return false, "No subschema matching instance."
    end
}

-- checks for existence as well as all of the listed options
Schema.register 'all' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            for key in ipairs(self.specification) do
                coroutine.yield(key, nil)
            end
        end)
    end,
    validate = function(self, instance, context) 
        if self.specification == nil or func.isempty(self.specification) then 
            return false, "All schema is empty -- so trivially nothing can match"
        end
        return validate_children(self, instance, context)
    end
}

-- nil is always true, 
Schema.register 'none' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            for key in ipairs(self.specification) do
                coroutine.yield(key, nil)
            end
        end)
    end,
    validate = function(self, instance, context) 
        if self.specification == nil or func.isempty(self.specification) then return true end
        for childschema, childinstance in self:iterate(instance, context) do 
            if childschema:validate(childinstance, context) then 
                return false, "Subschema matched instance"
            end 
        end 
        return true
    end
}

-- checks for nil or the other type
Schema.register 'maybe' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            if self.specification then
                coroutine.yield(1, nil)
            end 
        end)
    end,
    prevalidate = function(self, instance, context) 
        if instance == nil then return nil end 
        return prevalidate_children(self, instance, context)
    end,
    validate = function(self, instance, context) 
        if not instance then return true end
        return validate_children(self, instance, context)
    end,
    postvalidate = function(self, instance, context) 
        if instance == nil then return nil end 
        return postvalidate_children(self, instance, context)
    end
}

-- checks for number-only indexes and optionally an underlying schema on those values
Schema.register 'vec' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            if type(instance) ~= "table" then return end
            for i in ipairs(instance) do
                coroutine.yield(1, i)
            end
        end)
    end,
    prevalidate = prevalidate_children,
    validate = function(self, instance, context)
        if type(instance) ~= "table" then 
            return false, "Instance is not a table so also not a vec"
        end
        for key in pairs(instance) do
            if not (type(key) == "number" and math.floor(key) == key) then 
                return false, "Found non-integer key"
            end    
        end
        return validate_children(self, instance, context)
    end,
    postvalidate = postvalidate_children
}

-----------------------------------------------
-- Type schemas
-----------------------------------------------

-- checks for a number 
Schema.register 'num' {
    validate = function(self, instance)
        return type(instance) == "number", "The instance: `" .. tostring(instance) .. "` is not a number"
    end
}

-- checks for a number 
Schema.register 'func' {
    validate = function(self, instance)
        return type(instance) == "function", "The instance: `" .. tostring(instance) .. "` is not a function"
    end
}

-- checks for an integer 
Schema.register 'int' {
    validate = function(self, instance)
        return instance == math.floor(instance), "The instance: `" .. tostring(instance) .. "` is not an integer"
    end
}

-- checks for a nonnegative integer 
Schema.register 'uint' {
    validate = function(self, instance)
        return instance == math.floor(instance) and instance >= 0, "The instance: `" .. tostring(instance) .. "` is not a nonnegative integer"
    end
}

-- checks for a string 
Schema.register 'str' {
    validate = function(self, instance)
        return type(instance) == "string", "The instance: `" .. tostring(instance) .. "` is not a string"
    end
}

-- checks for a boolean 
Schema.register 'bool' {
    validate = function(self, instance)
        return type(instance) == "boolean", "The instance: `" .. tostring(instance) .. "` is not a boolean"
    end
}

-- checks for a thread 
Schema.register 'thr' {
    validate = function(self, instance)
        return type(instance) == "thread", "The instance: `" .. tostring(instance) .. "` is not a thread"
    end
}

-- checks for a table 
Schema.register 'table' {
    validate = function(self, instance)
        return type(instance) == "table", "The instance: `" .. tostring(instance) .. "` is not a table"
    end
}

-- checks for a table 
Schema.register 'nil' {
    validate = function(self, instance)
        return instance == nil, "The instance: `" .. tostring(instance) .. "` is not nil"
    end
}

-----------------------------------------------
-- Sugar schemas
-----------------------------------------------

-- checks for a date
Schema.register 'date' {
    validate = function(self, value)
        return type(value) == "number" and value >= 0
    end,
    isos = {
        format = {
            backward = function(self, value)
                local y, mo, d = value:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
                if not y then return end
                return os.time({
                    year = tonumber(y), month = tonumber(mo), day = tonumber(d),
                    hour = tonumber(0), min = tonumber(0), sec = tonumber(0), 
                    isdst = false 
                })
            end,
            forward = function(self, epoch)
                return os.date("%Y-%m-%d", epoch)
            end,
        }
    }
}

-- checks for a datetime
Schema.register 'datetime' {
    validate = function(self, value)
        return type(value) == "number" and value >= 0
    end,
    isos = {
        format = {
            backward = function(self, value)
                local y, mo, d, h, mi, s = value:match("^(%d%d%d%d)-(%d%d)-(%d%d)[T ](%d%d):(%d%d):(%d%d)$")
                if not y then return end
                return os.time({
                    year = tonumber(y), month = tonumber(mo), day = tonumber(d),
                    hour = tonumber(h), min = tonumber(mi), sec = tonumber(s), 
                    isdst = false 
                })
            end,
            forward = function(self, epoch)
                return os.date("%Y-%m-%d %H:%M:%S", epoch)
            end,
        }
    }
}

-----------------------------------------------
-- Descriptive schemas 
-----------------------------------------------

-- checks for a numeric range 
Schema.register 'rng' {
    validate = function(self, instance)
        local lower = self.specification[1] or self.specification.lower or "-inf"
        local upper = self.specification[2] or self.specification.upper or "inf"
        return (lower == "-inf" or lower <= instance) and (upper == "inf" or instance <= upper), "Range: " .. tostring(lower) .. " <= " .. tostring(instance) .. " <= " .. tostring(upper)
    end
}

-- checks for a metatable 
Schema.register 'hasmetatable' {
    validate = function(self, instance)
        if type(instance) ~= "table" then return false end
        if getmetatable(instance) and not self.specification then return true end
        if getmetatable(instance) == self.specification then return true end
        if type(self.specification) == "table" and getmetatable(instance) == self.specification.metatable then return true end
        return false 
    end
}

-- checks for an empty string or table 
Schema.register 'empty' {
    validate = function(self, instance)
        return #instance == 0, "Non-empty length of " .. tostring(#instance)
    end
}

-- checks for size of a table
Schema.register 'size' {
    validate = function(self, instance, context)
        local lower = (self.specification and (self.specification[1] or self.specification.lower)) or 0
        local upper = (self.specification and (self.specification[2] or self.specification.upper)) or "inf"
        local size = #instance
        return (lower == "-inf" or lower <= size) and (upper == "inf" or size <= upper), "Range: " .. tostring(lower) .. " <= " .. tostring(size) .. " <= " .. tostring(upper)
    end
}

-----------------------------------------------
-- Modifiers
-----------------------------------------------

-- registers a default value 
Schema.register 'default' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            coroutine.yield(1, nil)
        end)
    end,
    prevalidate = function(self, instance, context)
        if instance == nil then 
            local default_func = self.specification.default or self.specification[2]
            instance = default_func(self, instance, context)     
        end
        for childschema, childinstance in self:iterate(instance, context) do
            instance = childschema:prevalidate(childinstance, context)
        end
        return instance
    end,
    validate = validate_children,
    postvalidate = postvalidate_children
}

-- derive a value if nil
Schema.register 'derive' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            coroutine.yield(1, nil)
        end)
    end,
    prevalidate = function(self, instance, context)
        instance = self.specification.derive(self, instance, context)
        for childschema, childinstance in self:iterate(instance, context) do
            instance = childschema:prevalidate(childinstance, context)
        end
        return instance
    end,
    validate = validate_children,
    postvalidate = postvalidate_children
}

-- unformat when required 
Schema.register 'formatted' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            coroutine.yield(1, nil)
        end)
    end,
    prevalidate = function(self, instance, context) 
        if self:validate(instance) then return instance end 
        local result = self:unapply('format', instance, context)
        for childschema, childinstance in self:iterate(result, context) do
            result = childschema:prevalidate(childinstance, context)
        end
        return result
    end,
    validate = validate_children,
    postvalidate = postvalidate_children
}

-- format when required 
Schema.register 'serialized' {
    iterate = function(self, instance, context)
        return coroutine.wrap(function()
            coroutine.yield(1, nil)
        end)
    end,
    prevalidate = function(self, instance, context) 
        if self:validate(instance) then return instance end 
        local result = self:unapply('serialize', instance, context)
        for childschema, childinstance in self:iterate(result, context) do
            result = childschema:prevalidate(childinstance, context)
        end
        return result
    end,
    validate = validate_children,
    postvalidate = postvalidate_children
}

-----------------------------------------------
-- Rules
-----------------------------------------------

-- Prevalidate can return a value and it will override the value in the schema 
-- Prevalidate must be idempotent 

-- nil or false in validate are false 
-- everything else is true 
-- throwing an exception will invalidate it obviously 

-- Postvalidate can return a value and it will override the value in the schema 
-- Postvalidate must be idempotent 

-- isos must be isomorphisms 
-- except that errors are allowed on the way back, similar to prevalidate 

-----------------------------------------------
-- Usage
-----------------------------------------------

-- local schema = require 'lib.schema'

-- Schema.register 'str' {
    -- validate = function(value) 
    --     return type(value) == "string"
    -- end 
-- }

-- field4_schema = schema.new {
--     prevalidate = function(value)
--         value = value or 10 
--     end,
--     validate = function(value)
--         return type(value) == "number"
--     end,
--     postvalidate = function(value)
--         return value^2 
--     end
-- }

-- payload_schema = schema.atleast {
--     field1 = schema.str,
--     field2 = schema.number(),
--     field3 = schema.between(-10, 10),
--     field4 = field4_schema,
--     field5 = 6, -- a constant so check against the constant directly 
--     field6 = 'int', -- 
--     field7 = schema.any {
--         3,
--         4,
--         schema.all {
--             schema.number(),
--             7
--         }
--     }
-- }

-- payload_schema:validate(data)
-- payload_schema:resolve(data)


return Schema
