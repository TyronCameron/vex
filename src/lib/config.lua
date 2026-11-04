local lfs = require 'lib.lfs'

local Config = {}
Config.__index = function(tab, key)
    return rawget(Config, key) or rawget(rawget(tab, "properties"), key)
end

function Config.new(defaults)
    local properties = {}
    for key, value in pairs(defaults or {}) do properties[key] = value end
    return setmetatable({files = {}, properties = properties}, Config)
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
            for key, value in pairs(cfg) do
                self.properties[key] = value
            end
        end
    end
    return self
end

return Config
