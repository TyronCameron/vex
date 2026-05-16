
local func = require 'lib.func'

local format = {}

function format.json(val, indent, level)
    local pad = string.rep('  ', level or indent or 0)
    local pad_inner = string.rep('  ', (level or indent or 0) + 1)
    
    if type(val) == 'string' then
        return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    elseif type(val) == 'number' or type(val) == 'boolean' then
        return tostring(val)
    elseif val == nil then
        return 'null'
    elseif type(val) == 'table' then
        -- check if it's an array (all keys are sequential integers starting from 1)
        local is_array = true
        for k, v in pairs(val) do
            if type(k) ~= 'number' or k < 1 or k ~= math.floor(k) or k > #val then
                is_array = false
                break
            end
        end
        
        if is_array then
            if #val == 0 then return '[]' end
            local parts = {}
            for i, v in ipairs(val) do
                table.insert(parts, pad_inner .. format.json(v, indent, (level or indent or 0) + 1))
            end
            return '[\n' .. table.concat(parts, ',\n') .. '\n' .. pad .. ']'
        else
            if next(val) == nil then return '{}' end
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, pad_inner .. format.json(tostring(k), indent, (level or indent or 0) + 1) .. ': ' .. format.json(v, indent, (level or indent or 0) + 1))
            end
            return '{\n' .. table.concat(parts, ',\n') .. '\n' .. pad .. '}'
        end
    end
    return 'null'
end

local function csv_field(val)
    local s = tostring(val)
    if s:find('[,"\r\n]') then
        return '"' .. s:gsub('"', '""') .. '"'
    end
    return s
end

function format.csv(data)
    local rows = {}
    local fields = func.keys(data[1])
    table.insert(rows, table.concat(fields, ','))
    for _, task in ipairs(data) do 
        local rowdata = func.imap(fields, function(field) return csv_field(task[field]) end)
        table.insert(rows, table.concat(rowdata, ','))
    end 
    return table.concat(rows, '\n')
end

return format