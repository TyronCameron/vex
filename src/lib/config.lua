local lfs = require 'lib.lfs'

local Config = {}
Config.__index = function(tab, key)
    return rawget(Config, key) or rawget(rawget(tab, "properties"), key)
end

local function ismap(value)
    if type(value) ~= 'table' then return false end
    for key in pairs(value) do
        if type(key) ~= 'number' then return true end
    end
    return false
end

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end

-- maps merge key by key, anything else (lists included) in the second replaces the first
function Config.merge(base, over)
    local result = copy(base)
    for key, value in pairs(over) do
        if ismap(value) and ismap(result[key]) then
            result[key] = Config.merge(result[key], value)
        else
            result[key] = copy(value)
        end
    end
    return result
end

function Config.new(defaults)
    return setmetatable({files = {}, properties = copy(defaults or {})}, Config)
end

function Config:registerpath(path)
    if path then table.insert(self.files, path) end
    return self
end

-- later files override earlier ones; returns nil, path, err for the first file that does not run to a table
function Config:loadall()
    for _, path in ipairs(self.files) do
        if lfs.attributes(path, 'mode') == 'file' then
            local ok, cfg = pcall(dofile, path)
            if not ok or type(cfg) ~= 'table' then
                return nil, path, ok and 'it must return a table, not ' .. type(cfg) or cfg
            end
            self.properties = Config.merge(self.properties, cfg)
        end
    end
    return self
end

return Config
