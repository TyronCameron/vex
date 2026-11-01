local function parse_yaml_value(s)
    s = s:match("^%s*(.-)%s*$")
    if s == "true" then return true end
    if s == "false" then return false end
    local n = tonumber(s)
    if n then return n end
    local flow = not s:match("^%[%[") and s:match("^%[(.*)%]$")
    if flow then
        local list = {}
        if flow:match("^%s*$") then return list end
        for quote, item in (flow .. ","):gmatch('%s*(["\']?)(.-)%1%s*,') do
            list[#list + 1] = quote == "" and parse_yaml_value(item) or item
        end
        return list
    end
    return (s:match('^"(.*)"$') or s:match("^'(.*)'$") or s)
end

local function keyvalue(s)
    local key, value = s:match("^([^\"'%[{][^:]-):%s+(.*)$")
    if key then return key, value end
    key = s:match("^([^\"'%[{][^:]-):$")
    return key, key and ""
end

local parseblock

local function parseentry(lines, i, indent, value)
    local nextline = lines[i + 1]
    if value ~= "" then return parse_yaml_value(value), i + 1 end
    if nextline and (nextline.indent > indent or nextline.indent == indent and nextline.text:match("^%-")) then
        return parseblock(lines, i + 1, nextline.indent)
    end
    return nil, i + 1
end

function parseblock(lines, i, indent)
    local isseq = lines[i].text:match("^%-") ~= nil
    local block = {}
    while lines[i] and lines[i].indent == indent and (lines[i].text:match("^%-") ~= nil) == isseq do
        if isseq then
            local dash, item = lines[i].text:match("^(%-%s*)(.*)$")
            if keyvalue(item) then
                lines[i] = {indent = indent + #dash, text = item}
                block[#block + 1], i = parseblock(lines, i, indent + #dash)
            else
                block[#block + 1], i = parseentry(lines, i, indent + 1, item)
            end
        else
            local key, value = keyvalue(lines[i].text)
            if not key then break end
            block[key], i = parseentry(lines, i, indent, value)
        end
    end
    return block, i
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
            local keys = {}
            for k in pairs(v) do keys[#keys + 1] = k end
            table.sort(keys)
            local lines = {}
            for _, k in ipairs(keys) do
                lines[#lines + 1] = inner .. k .. ": " .. to_yaml_value(v[k], inner)
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

        if not content:match("^%-%-%-\n") then return nil end

        local frontmatter, body = content:match("^%-%-%-\n(.-)\n%-%-%-\n(.*)$")
        assert(frontmatter, "the frontmatter is never closed")
        frontmatter = frontmatter:match("^%s*(.-)%s*$")
        assert(#frontmatter > 0, "frontmatter must not be empty")

        local lines = {}
        for line in frontmatter:gmatch("[^\n]+") do
            local indent, text = line:match("^(%s*)(.-)%s*$")
            if text ~= "" and not text:match("^#") then lines[#lines + 1] = {indent = #indent, text = text} end
        end
        local task, nextline = parseblock(lines, 1, lines[1].indent)
        assert(nextline > #lines, "cannot read the line `" .. tostring(lines[nextline] and lines[nextline].text) .. "`")
        task.vexbody = body

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