
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
    if val == nil then return '' end
    if type(val) == 'table' then
        val = table.concat(func.imap(val, function(item) return tostring(item) end), ',')
    end
    local s = tostring(val)
    if s:find('[,"\r\n]') or s:find('^%s') or s:find('%s$') then
        return '"' .. s:gsub('"', '""') .. '"'
    end
    return s
end

function format.csv(data)
    local rows = {}
    local seen = {}
    for _, task in ipairs(data) do
        for field in pairs(task) do seen[field] = true end
    end
    local fields = func.keys(seen)
    table.sort(fields)
    table.insert(rows, table.concat(func.imap(fields, csv_field), ','))
    for _, task in ipairs(data) do 
        local rowdata = func.imap(fields, function(field) return csv_field(task[field]) end)
        table.insert(rows, table.concat(rowdata, ','))
    end 
    return table.concat(rows, '\n')
end

function format.icstext(text)
    return (text:gsub('[\\;,]', '\\%0'):gsub('\r?\n', '\\n'))
end

local function ics_fold(line)
    local folded, limit = {}, 75
    while #line > limit do
        local cut = limit
        while cut > 1 and line:byte(cut + 1) >= 0x80 and line:byte(cut + 1) < 0xC0 do cut = cut - 1 end
        table.insert(folded, line:sub(1, cut))
        line = line:sub(cut + 1)
        limit = 74
    end
    table.insert(folded, line)
    return table.concat(folded, '\r\n ')
end

-- events are lists of {name, value, params = 'X=Y' or nil, text = true to escape value}
function format.ics(events, prodid)
    local lines = {'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:' .. prodid, 'CALSCALE:GREGORIAN'}
    for _, event in ipairs(events) do
        table.insert(lines, 'BEGIN:VEVENT')
        for _, property in ipairs(event) do
            local value = property.text and format.icstext(tostring(property.value)) or tostring(property.value)
            table.insert(lines, property.name .. (property.params and ';' .. property.params or '') .. ':' .. value)
        end
        table.insert(lines, 'END:VEVENT')
    end
    table.insert(lines, 'END:VCALENDAR')
    return table.concat(func.imap(lines, ics_fold), '\r\n') .. '\r\n'
end

return format