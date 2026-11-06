local lfs = require 'lib.lfs'
local func = require 'lib.func'

local Config = {}
Config.__index = function(tab, key)
    return rawget(Config, key) or rawget(rawget(tab, "properties"), key)
end

function Config.new(defaults)
    return setmetatable({files = {}, properties = func.merge({}, defaults or {})}, Config)
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
            self.properties = func.merge(self.properties, cfg)
        end
    end
    return self
end

return Config
