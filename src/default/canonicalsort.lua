local field_order = { vexid = 1, vextype = 2, description = 3 }

local function sort_keys(keys)
    table.sort(keys, function(a, b)
        local ia, ib = field_order[a], field_order[b]
        if ia and ib then return ia < ib end
        if ia then return true end
        if ib then return false end
        return a < b
    end)
end

return function(frontmatter)
    local keys = {}
    for k in pairs(frontmatter) do
        table.insert(keys, k)
    end
    sort_keys(keys)

    local i = 0
    return function()
        i = i + 1
        local k = keys[i]
        if k ~= nil then
            return k, frontmatter[k]
        end
    end
end