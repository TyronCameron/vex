local focus = require 'core.focus'
local vexdex = require 'core.vexdex'

local function folder(task, field)
    if field == 'parent' then
        local chain = focus.focus(task.vexid):reversetree('children'):get()
        local ancestors = {}
        for i = #chain, 2, -1 do table.insert(ancestors, chain[i].vexid) end
        return table.concat(ancestors, '/')
    end
    return task[field] ~= nil and tostring(task[field]) or ''
end

return {
    path = function(taskmanager, config, vexid)
        local task = vexdex:get(vexid)
        local folders = {}
        for _, field in ipairs(task and config.groupby or {}) do
            local name = folder(task, field)
            if name ~= '' then table.insert(folders, name) end
        end
        table.insert(folders, vexid .. '.md')
        return table.concat(folders, '/')
    end
}
