local cli = require 'lib.cli'
local func = require 'lib.func'
local vexdex = require 'core.vexdex'

local function folder(value)
    local name = tostring(value):gsub('[%c/\\:*?"<>|]', '-')
    if name:match('^%.+$') then name = name:gsub('%.', '-') end
    return name
end

local function folders(groupby, task)
    local names = {}
    for _, field in ipairs(groupby) do
        local value = task[field]
        for _, element in ipairs(type(value) == 'table' and value or {value}) do
            if element ~= '' then table.insert(names, folder(element)) end
        end
    end
    return names
end

return {
    path = function(taskmanager, config, vexid)
        local groupby = (config.paths or {}).groupby or {}
        if type(groupby) ~= 'table' or not func.all(groupby, function(field) return type(field) == 'string' end) then
            cli:throw('bad-groupby', groupby)
        end
        local task = vexdex:get(vexid)
        local names = task and folders(groupby, task) or {}
        table.insert(names, vexid .. '.md')
        return table.concat(names, '/')
    end
}
