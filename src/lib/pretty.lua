
local pretty = {}

function pretty.table_to_string(val, indent, visited)
    indent   = indent or 0
    visited  = visited or {}
    local t  = type(val)

    if t == "nil"     then return "nil"
    elseif t == "boolean" then return tostring(val)
    elseif t == "number"  then return tostring(val)
    elseif t == "string"  then return string.format("%q", val)
    elseif t == "function" then return tostring(val)  -- e.g. "function: 0x..."
    elseif t == "userdata" then return tostring(val)
    elseif t == "thread"   then return tostring(val)
    elseif t ~= "table"    then return tostring(val)
    end

    -- cycle detection
    if visited[val] then return "<circular>" end
    visited[val] = true

    local mt = getmetatable(val)
    if mt and mt.__tostring then
        visited[val] = nil
        return tostring(val)
    end

    local pad     = string.rep("  ", indent)
    local pad_in  = string.rep("  ", indent + 1)
    local parts   = {}

    -- collect and sort keys for deterministic output
    local keys = {}
    for k in pairs(val) do table.insert(keys, k) end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta == tb then
            if ta == "number" or ta == "string" then return a < b end
            return tostring(a) < tostring(b)
        end
        return ta < tb  -- group by type: number < string < ...
    end)

    for _, k in ipairs(keys) do
        local v       = val[k]
        local key_str = type(k) == "string" and k or ("[" .. pretty.table_to_string(k, indent + 1, visited) .. "]")
        local val_str = pretty.table_to_string(v, indent + 1, visited)
        table.insert(parts, pad_in .. key_str .. " = " .. val_str)
    end

    visited[val] = nil  -- allow the same table to appear in separate branches

    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
end

return pretty