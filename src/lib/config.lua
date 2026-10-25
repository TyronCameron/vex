local lfs = require 'lib.lfs'

local Config = {}
Config.__index = function(tab, key)
    return rawget(Config, key) or rawget(rawget(tab, "properties"), key)
end

function Config.new()
    return setmetatable({files = {}, properties = {}}, Config)
end

function Config:registerpath(path)
    if path then table.insert(self.files, path) end
    return self
end

function Config:loadall()
    for _, path in ipairs(self.files) do
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