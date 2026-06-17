
local lfs = require 'lib.lfs'

local Plugin = {}
Plugin.__index = Plugin


-- ── Internals ──────────────────────────────────────────────────────────────

-- load package into plugin
local function load(plugin, name)
    local entry = plugin.plugins[name]
    if not entry.loaded then
        local ok, mod = pcall(require, "plugin." .. name)
        if not ok then
            assert(mod:find("module '.-' not found"), mod)
            mod = require("default." .. name)
        end
        entry.mod = mod
        entry.loaded = true
    end
    return entry.mod
end

-- check if name in members
local function member_of(name, members)
    for _, m in ipairs(members) do
        if m == name then return true end
    end
    return false
end

-- ── Main ──────────────────────────────────────────────────────────────

function Plugin.new()
    return setmetatable({
        plugins = {},
        sets = {},
        disabled = {},
    }, Plugin)
end

-- Register a single plugin by name
function Plugin:add(name)
    assert(type(name) == "string", "plugin name must be a string")
    assert(not self.plugins[name], "plugin '" .. name .. "' already registered")
    assert(not self.sets[name], "'" .. name .. "' is already a set name")
    self.plugins[name] = { loaded = false, mod = nil }
    return self
end

-- Register a folder of plugins
function Plugin:addall(plugin_dir)
    for filename in lfs.dir(plugin_dir) do
        if filename ~= "." and filename ~= ".." then
            if lfs.attributes(plugin_dir .. '/' .. filename, 'mode') == 'directory'
                or filename:find("%.lua") then
                self:add(filename:gsub("%.lua", ""))
            end
        end
    end
    return self
end

-- Register a named set: a group of plugins where exactly one is active
function Plugin:addenum(name, members, active)
    assert(type(name) == "string", "set name must be a string")
    assert(type(members) == "table", "members must be a list")
    assert(#members > 0, "set must have at least one member")
    assert(not self.sets[name], "set '" .. name .. "' already registered")
    assert(not self.plugins[name],   "'" .. name .. "' is already a plugin name")

    active = active or members[1]
    assert(member_of(active, members), "active '" .. active .. "' is not in set '" .. name .. "'")

    for _, m in ipairs(members) do
        if not self.plugins[m] then
            self.plugins[m] = { loaded = false, mod = nil }
        end
    end

    self.sets[name] = { members = members, active = active }
    return self
end

-- Enable a previously disabled plugin or set.
function Plugin:enable(name)
    self.disabled[name] = nil
    return self
end
-- Disable a plugin or set by name.
function Plugin:disable(name)
    self.disabled[name] = true
    return self
end

-- Get the active underlying module name
function Plugin:getname(name)
    if self.plugins[name] then return name end 
    return self.sets[name] and self.sets[name].active
end

-- Get a single plugin module by name.
function Plugin:get(name)
    local resolved = self:getname(name)
    assert(resolved, "unknown plugin or set '" .. name .. "'")
    if self.disabled[resolved] then return nil end
    return load(self, resolved)
end

-- Reload a plugin's module from disk, bypassing the require cache.
function Plugin:reload(name)
    local resolved = self:getname(name)
    assert(resolved, "unknown plugin or set '" .. name .. "'")
    local entry = self.plugins[resolved]
    package.loaded["plugin." .. resolved] = nil
    entry.loaded = false
    entry.mod = nil
    return self:get(resolved)
end

-- Switch which member is active in a set (at runtime).
function Plugin:select(set_name, member)
    local s = self.sets[set_name]
    assert(s, "unknown set '" .. set_name .. "'")
    assert(member_of(member, s.members),
        "'" .. member .. "' is not in set '" .. set_name .. "'")
    s.active = member
    return self
end

-- Iterate all enabled plugins: callback(name, mod)
function Plugin:each(fn)
    for name, _ in pairs(self.plugins) do
        if not self.disabled[name] then
            fn(name, load(self, name))
        end
    end
end

return Plugin.new()