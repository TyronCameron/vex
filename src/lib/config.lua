local lfs = require 'lib.lfs'

local Config = {}
Config.__index = function(tab, key)
    return rawget(Config, key) or rawget(rawget(tab, "properties"), key)
end

function Config.new()
    return setmetatable({paths = {}, properties = {}}, Config)
end

function Config:registerpath(path)
    table.insert(self.paths, path)
    return self
end

function Config:loadall()
    for _, path in ipairs(self.paths) do
        local ok, cfg = pcall(dofile, path)
        if ok then 
            for key, value in pairs(cfg) do 
                self.properties[key] = value
            end -- intentionally overwriting prior paths with later values
        else 
            print('Warning: could not read / execute config at ' .. path)
        end 
    end
    return self 
end

return Config