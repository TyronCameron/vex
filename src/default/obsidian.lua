local function parse_yaml_value(s)
    s = s:match("^%s*(.-)%s*$")
    if s == "true" then return true end
    if s == "false" then return false end
    local n = tonumber(s)
    if n then return n end
    return (s:match('^"(.*)"$') or s:match("^'(.*)'$") or s)
end

local function to_yaml_value(v)
    local t = type(v)
    if t == "boolean" or t == "number" then return tostring(v) end
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
            for line in frontmatter:gmatch("[^\n]+") do
                local key, value = line:match("^([%w_]+):%s*(.*)$")
                if key then
                    task[key] = parse_yaml_value(value)
                end
            end
            task.body = body
        else
            task.body = content
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