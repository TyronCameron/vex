
local func = require "lib.func"
local pretty = require "lib.pretty"

local templates = {}

local schema = {
    types = {},
    validations = {}
}
schema.__index = schema

local function classify(template)
    if template and type(template) == "table" and template.type and schema.types[template.type] then return "schema" end
    if template and type(template) == "string" and schema.types[template] then return "direct" end
    return "constant"
end

local function create_schema_from_string(str)
    assert(type(str) == "string", "Not receiving a string but expecting one")
    assert(templates[str], "The string " .. str .. " does not exist in templates. Here are alternatives: " .. pretty.table(func.keys(templates)))
    assert(type(templates[str]) == "function", "Something is wrong in the schema file ... we have something which is not a function when it should be")
    return templates[str]()
end 

local function err_msg(self, instance) 
    local schema_info, instance_info;
    if classify(self) == "schema" then
        schema_info = self.type .. " " 
        if type(self.allowed) == "table" then schema_info = schema_info .. pretty.table(self.allowed) 
        else schema_info = schema_info .. tostring(self.allowed) end 
    elseif classify(self) == "direct" then 
        return err_msg(create_schema_from_string(template), instance)
    else 
        schema_info = self .. "::constant"
    end 
    instance_info = tostring(instance) .. "::" .. type(instance)
    return "Instance and schema do not match. Instance: " .. instance_info .. "; Schema: " .. schema_info
end

function schema.register(schema_type, func)
    assert(type(schema_type) == "string", "Cannot create a new schema_type that is not a string")
    schema.types[schema_type] = true
    templates[schema_type] = function(tab)
        local err_func = (type(tab) == "table" and tab.on_error) or err_msg
        return setmetatable({type = schema_type, allowed = tab or {}, validate = func, on_error = err_func}, schema)
    end 
end

local function validate(template, instance)
    local valid = false
    local err_msg = nil
    if classify(template) == "schema" then 
        valid = template:validate(instance) 
        if not valid then err_msg = template.on_error(template, instance) end 
    elseif classify(template) == "direct" then 
        local sch = create_schema_from_string(template)
        valid, err_msg = sch:validate(instance)
    else
        local sch = templates.constant(template)
        valid, err_msg = sch:validate(instance)
        if not valid then 
            err_msg = "Schema and instance do not match. Schema only allows for a constant: " 
                .. tostring(template) .. "::" .. type(template) 
                .. " ; Instance: " .. tostring(instance) .. "::" .. type(instance) end 
    end 
    return valid, err_msg
end

function schema.validations.schema(self, instance)
    local valid, err_msg = schema.validations.atleast(self, instance) 
    if valid then valid, err_msg = schema.validations.atmost(self, instance) end 
    return valid, err_msg
end

function schema.validations.atmost(self, instance)
    for k,v in pairs(instance) do
        local valid, err_msg = validate(self.allowed[k], v)
        if not valid and err_msg then err_msg = k .. ": " .. err_msg end
        if not valid then return valid, err_msg end 
    end
    return true
end

function schema.validations.atleast(self, instance)
    if not instance then return false end 
    for k,lower_schema in pairs(self.allowed) do
        local valid, err_msg = validate(lower_schema, instance[k])
        if not valid and err_msg then err_msg = k .. ": " .. err_msg end
        if not valid then return valid, err_msg end 
    end
    return true
end

-- checks for existence as well as any of the listed options
function schema.validations.any(self, instance)
    if instance == nil then return false end
    if self.allowed == nil or func.isempty(self.allowed) then return true end
    return func.any(self.allowed, function(x) return validate(x, instance) end)
end

-- checks for existence as well as all of the listed options
function schema.validations.all(self, instance)
    if instance == nil then return false end
    if self.allowed == nil or func.isempty(self.allowed) then return false end
    return func.all(self.allowed, function(x) return validate(x, instance) end)
end

-- nil is always true, 
function schema.validations.none(self, instance)
    if instance == nil then return true end
    if self.allowed == nil or func.isempty(self.empty) then return true end
    return not func.any(self.allowed, function(x) return validate(x, instance) end)
end

-- checks for nil or the other type
function schema.validations.maybe(self, instance)
    if instance == nil then return true end
    return validate(self.allowed, instance)
end

function schema.validations.num(self, instance)
    return type(instance) == "number"
end

function schema.validations.int(self, instance)
    return instance == math.floor(instance)
end

function schema.validations.uint(self, instance)
    return instance == math.floor(instance) and instance >= 0
end

function schema.validations.int_rng(self, instance)
    local intvalid = instance == math.floor(instance) 
    local lowervalid = false
    local uppervalid = false
    local lower = self.allowed[1] or self.allowed.lower 
    if lower == "-inf" then 
        lowervalid = true 
    else 
        lowervalid = lower <= instance 
    end 
    local upper = self.allowed[2] or self.allowed.upper
    if upper == "inf" then 
        uppervalid = true 
    else 
        uppervalid = upper <= instance 
    end 
    return valid and lowervalid and uppervalid
end

function schema.validations.rng(self, instance)
    local intvalid = type(instance) == "number"
    local lowervalid = false
    local uppervalid = false
    local lower = self.allowed[1] or self.allowed.lower 
    if lower == "-inf" then 
        lowervalid = true 
    else 
        lowervalid = lower <= instance 
    end 
    local upper = self.allowed[2] or self.allowed.upper
    if upper == "inf" then 
        uppervalid = true 
    else 
        uppervalid = upper <= instance 
    end 
    return valid and lowervalid and uppervalid
end

function schema.validations.str(self, instance)
    return type(instance) == "string"
end

function schema.validations.bool(self, instance)
    return type(instance) == "boolean"
end

function schema.validations.thr(self, instance)
    return type(instance) == "thread"
end

function schema.validations.anytable(self, instance)
    return type(instance) == "table"
end

function schema.validations.hasmetatable(self, instance)
    if type(instance) ~= "table" then return false end
    if getmetatable(instance) then return true end
    return false 
end

function schema.validations.vec(self, instance)
    if type(instance) ~= "table" then return false end
    local allowed = self.allowed.type or self.allowed[1]
    for k,v in pairs(instance) do
        if not (type(k) == "number" and math.floor(k) == k) then return false end
        if not allowed:validate(v) then return false end
    end
    return true
end

function schema.validations.tuple(self, instance)
    if type(instance) ~= "table" then return false end
    local allowed = self.allowed
    if #allowed == 0 and allowed.type and allowed.size then 
        allowed = func.rep(allowed.type, allowed.size)
    end 
    if #instance ~= #allowed then return false end
    for k, v in pairs(instance) do
        if not (type(k) == "number" and math.floor(k) == k) then return false end
        if not allowed[k] then return false end
        if not validate(allowed[k], v) then return false end
    end
    return true
end

function schema.validations.constant(self, instance)
    return self.allowed == instance
end

function schema.validations.constraint(self, instance)
    if type(self.allowed) == "function" then return self.allowed(instance) end 
    if type(self.allowed.allow) == "function" then return self.allowed.allow(instance) end 
    if type(self.allowed[1]) == "function" then return self.allowed[1](instance) end 
    assert(false, "Schema set up wrong. Don't know how to handle the contraint")
end

for k,validation in pairs(schema.validations) do
    schema.register(
        k, 
        function(self, instance)
            local valid, err_msg = validation(self, instance)
            if not valid and err_msg == nil then err_msg = self.on_error(self, instance) end 
            return valid, err_msg
        end
    )
end

return templates
