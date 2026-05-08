
local PrettyString = {}
PrettyString.__index = PrettyString
PrettyString.__tostring = function(self)
    if #self == 1 then return self[1] end
    local codes = {}
    for i = 2, #self do
        table.insert(codes, self[i])
    end
    return "\27[" .. table.concat(codes, ";") .. "m" .. self[1] .. "\27[0m"
end
setmetatable(PrettyString, {
    __call = function(cls, text, ...)
        local instance = PrettyString.new(text)
        if select("#", ...) > 0 then
            instance:style(...)
        end
        return instance
    end
})

local styles = {
    reset = 0,
    bold = 1,
    dim = 2,
    italic = 3,
    underline = 4,
    blink = 5,
    reverse = 7,
    strike = 9
}

local function bg(tab)
    return setmetatable(tab, {__name = "bg"})
end 

local colors = {
    black          = {   0,   0,   0 },
    red            = { 205,  49,  49 },
    green          = {  13, 188, 121 },
    yellow         = { 229, 229,  16 },
    blue           = {  36, 114, 200 },
    magenta        = { 188,  63, 188 },
    cyan           = {  17, 168, 205 },
    white          = { 229, 229, 229 },
    bright_black   = { 102, 102, 102 },
    bright_red     = { 241,  76,  76 },
    bright_green   = {  35, 209, 139 },
    bright_yellow  = { 245, 245,  67 },
    bright_blue    = {  59, 142, 234 },
    bright_magenta = { 214, 112, 214 },
    bright_cyan    = {  41, 184, 219 },
    bright_white   = { 255, 255, 255 },
    bg_black          = bg {   0,   0,   0 },
    bg_red            = bg { 205,  49,  49 },
    bg_green          = bg {  13, 188, 121 },
    bg_yellow         = bg { 229, 229,  16 },
    bg_blue           = bg {  36, 114, 200 },
    bg_magenta        = bg { 188,  63, 188 },
    bg_cyan           = bg {  17, 168, 205 },
    bg_white          = bg { 229, 229, 229 },
    bg_bright_black   = bg { 102, 102, 102 },
    bg_bright_red     = bg { 241,  76,  76 },
    bg_bright_green   = bg {  35, 209, 139 },
    bg_bright_yellow  = bg { 245, 245,  67 },
    bg_bright_blue    = bg {  59, 142, 234 },
    bg_bright_magenta = bg { 214, 112, 214 },
    bg_bright_cyan    = bg {  41, 184, 219 },
    bg_bright_white   = bg { 255, 255, 255 },
}

local function rgb(r,g,b)
    if type(r) == "string" and not g and not b then 
        r,g,b = unpack(colors[r])
    end 
    return tostring(r) .. ";" .. tostring(g) .. ";" .. tostring(b)
end 

local function colorise(style)
    assert(#style == 3, "Cannot apply rgb if not exactly 3 elements")
    local mt = getmetatable(style)
    local startcode = (mt and mt.__name == "bg") and "48;2;" or "38;2;"
    return startcode .. rgb(unpack(style))
end

local function tocode(style)
    if type(style) == "table" then 
        return colorise(style)
    end 
    if colors[style] then return colorise(colors[style]) end 
    if styles[style] then return tostring(styles[style]) end 
    assert(false, "Got to an error in pretty style. No style of name " .. tostring(style) .. " found!")
end 

function PrettyString.new(text)
    return setmetatable({text}, PrettyString)
end

function PrettyString:style(...)
    local stylenames = {...}
    for _, style in ipairs(stylenames) do
        table.insert(self, tocode(style))
    end
    return self
end

function PrettyString:fg(tab)
    table.insert(self, tab)
    return self
end

function PrettyString:bg(tab)
    table.insert(self, bg(tab))
    return self
end

-- print(PrettyString("hello", "bold"))
-- print(PrettyString("hello", "red"))
-- print(PrettyString("hello", "red", "bold", "strike"))
-- print(PrettyString("hello", "dim", "underline"))

local pretty = {style = {}}

-- function pretty.styles.reset()
--     return nil
-- end

function pretty.string(tab, ...)
    local prettystr;
    if type(tab) == "table" then 
        prettystr = PrettyString(unpack(tab))
    else 
        prettystr = PrettyString(tab, ...)
    end
    return tostring(prettystr)
end 

function pretty.table(val, indent, visited)
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
        local key_str = type(k) == "string" and k or ("[" .. pretty.table(k, indent + 1, visited) .. "]")
        local val_str = pretty.table(v, indent + 1, visited)
        table.insert(parts, pad_in .. key_str .. " = " .. val_str)
    end

    visited[val] = nil  -- allow the same table to appear in separate branches

    if #parts == 0 then return "{}" end
    return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
end

function pretty.markdown(md)
  md = md:gsub("^# (.-)\n", "\27[1m%1\27[0m\n")
  md = md:gsub("%*%*(.-)%*%*", "\27[1m%1\27[0m")
  md = md:gsub("%*(.-)%*", "\27[3m%1\27[0m")
  return md
end

function pretty.write(path, value)
    local f = assert(io.open(path, "w"))
    f:write(pretty.table(value))
    f:close()
end 

return pretty