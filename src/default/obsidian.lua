local function parse_yaml_value(s)
    s = s:match("^%s*(.-)%s*$")
    if s == "true" then return true end
    if s == "false" then return false end
    local n = tonumber(s)
    if n then return n end
    return (s:match('^"(.*)"$') or s:match("^'(.*)'$") or s)
end

local function to_yaml_value(v, indent)
    indent = indent or ""
    local t = type(v)
    if t == "boolean" or t == "number" then return tostring(v) end
    if t == "table" then
        -- An empty Lua table can't tell array from map; every field that round-trips
        -- through here as one is schema.vec-typed, so "[]" (empty YAML sequence) is correct.
        if next(v) == nil then return "[]" end
        local inner = indent .. "  "
        -- Detect array: all keys are sequential integers
        local is_array = #v > 0
        if is_array then
            local lines = {}
            for _, item in ipairs(v) do
                lines[#lines + 1] = inner .. "- " .. to_yaml_value(item, inner)
            end
            return "\n" .. table.concat(lines, "\n")
        else
            local lines = {}
            for k, val in pairs(v) do
                lines[#lines + 1] = inner .. k .. ": " .. to_yaml_value(val, inner)
            end
            return "\n" .. table.concat(lines, "\n")
        end
    end
    -- String
    local s = tostring(v)
    if s:match("[:#%[%]{},&*?|>'\"%@`]") or s:match("^%s") or s:match("%s$") then
        return '"' .. s:gsub('"', '\\"') .. '"'
    end
    return s
end

return {
    read = function(path)
        local f = assert(io.open(path, "r"))
        local content = f:read("*a")
        f:close()

        local task = {}
        local frontmatter, body = content:match("^%-%-%-\n(.-)\n%-%-%-\n(.*)$")
        frontmatter = frontmatter:match("^%s*(.-)%s*$")
        assert(#frontmatter > 0, "frontmatter must not be empty")

        if frontmatter then
            local lastkey = nil
            for line in frontmatter:gmatch("[^\n]+") do
                local item = line:match("^%s+%-%s*(.*)$")
                if item and lastkey then
                    if type(task[lastkey]) ~= "table" then task[lastkey] = {} end
                    table.insert(task[lastkey], parse_yaml_value(item))
                else
                    local key, value = line:match("^([%w_]+):%s*(.*)$")
                    if key then
                        task[key] = (value == "[]") and {} or parse_yaml_value(value)
                        lastkey = key
                    end
                end
            end
            task.vexbody = body
        else
            task.vexbody = content
        end

        return task
    end,

    write = function(path, frontmatter_iter, body)
        local f = assert(io.open(path, "w"))

        f:write("---\n")
        for k, v in frontmatter_iter do
            f:write(k .. ": " .. to_yaml_value(v) .. "\n")
        end
        f:write("---\n")

        if body then
            f:write(body)
        end

        f:close()
    end
}