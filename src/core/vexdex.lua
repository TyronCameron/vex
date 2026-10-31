
local lfs = require "lib.lfs"
local cli = require "lib.cli"
local pretty = require 'lib.pretty'
local binser = require 'lib.binser'
local lfsext = require 'lib.lfsext'
local func = require 'lib.func'
local event = require 'lib.event'
local hash = require 'lib.hash'

local VexDex = {}
VexDex.__index = VexDex

function VexDex.new(path)
    path = path or lfs.currentdir()
    local found = lfsext.rootdir(path)
    if not found then  
        cli:throw("not-vexed")
    end
    local this = setmetatable({
        path = found,
        index = {},
        backlinks = {},
        paths = {},
        fingerprints = {},
        mtimes = {},
        dirty = false
    }, VexDex)
    return this:ensureindex()
end

function VexDex:unsafe_add(vexid, task)
    self.index[vexid] = task
    self.fingerprints[vexid] = self:fingerprint(task)
    self.dirty = true
    return self
end

function VexDex:add(vexid, storage)
    self:unsafe_add(vexid, storage)
    return self:writeindex()
end

function VexDex:unsafe_remove(vexid)
    self.index[vexid] = nil
    self.backlinks[vexid] = nil
    self.paths[vexid] = nil
    self.fingerprints[vexid] = nil
    self.mtimes[vexid] = nil
    self.dirty = true
    return self:unsafe_link(vexid, {})
end

function VexDex:remove(vexid)
    self:unsafe_remove(vexid)
    return self:writeindex()
end

function VexDex:linksto(vexid)
    local sources = func.keys(self.backlinks[vexid] or {})
    table.sort(sources)
    return sources
end

function VexDex:unsafe_link(vexid, links)
    self.dirty = true
    for target, sources in pairs(self.backlinks) do
        sources[vexid] = nil
        if next(sources) == nil then self.backlinks[target] = nil end
    end
    for _, target in ipairs(links) do
        self.backlinks[target] = self.backlinks[target] or {}
        self.backlinks[target][vexid] = true
    end
    return self
end

function VexDex:link(vexid, links)
    self:unsafe_link(vexid, links)
    return self:writeindex()
end

function VexDex:unsafe_locate(vexid, path)
    if self.paths[vexid] ~= path then self.dirty = true end
    self.paths[vexid] = path
    return self
end

-- records the mtime of a task's file as vex last saw it
function VexDex:unsafe_stamp(vexid, path)
    local mtime = self.listed and self.listed[path] or lfsext.mtime(path)
    if self.mtimes[vexid] ~= mtime then self.dirty = true end
    self.mtimes[vexid] = mtime
    return self
end

function VexDex:taskroot()
    return self.path .. '/' .. require('core.config').taskfolder
end

-- the indexed vexids whose files changed or went missing since their mtimes were stamped, and the files under the task folder that no indexed task is at
function VexDex:updated()
    self.listed = lfsext.mtimes(self:taskroot())
    local changed, known = {}, {}
    for vexid, relpath in pairs(self.paths) do
        local path = self:taskroot() .. '/' .. relpath
        known[path] = true
        if self.listed[path] ~= self.mtimes[vexid] then table.insert(changed, vexid) end
    end
    table.sort(changed)
    return changed, func.ifilter(func.sortedkeys(self.listed), function(path) return not known[path] end)
end

-- a hash of a task, leaving out the fields config.fingerprint.exclude names
function VexDex:fingerprint(task)
    local plain = func.map(task, function(value) return value end)
    for _, field in ipairs((require('core.config').fingerprint or {}).exclude or {}) do plain[field] = nil end
    return hash.fnv1a(pretty.table(plain))
end

-- whether a task differs from the one last indexed under its vexid
function VexDex:changed(vexid, task)
    return self.fingerprints[vexid] ~= nil and self.fingerprints[vexid] ~= self:fingerprint(task)
end

function VexDex:get(vexid)
    return self.index[vexid]
end

function VexDex:getfocus()
    return self.focus or self:readfocus() and self.focus
end 

function VexDex:setfocus(focus)
    self.focus = focus
    self:writefocus()
    return self
end 

function VexDex:vexpath(file)
    return self.path .. '/.vex/' .. file
end

function VexDex:readindex()
    local results = {binser.readFile(self:vexpath("vexdex/index.bin"))}
    self.index = results[1][1]
    if lfs.attributes(self:vexpath("vexdex/backlinks.bin"), "mode") == "file" then
        local backlinks = {binser.readFile(self:vexpath("vexdex/backlinks.bin"))}
        self.backlinks = backlinks[1][1]
    end
    if lfs.attributes(self:vexpath("vexdex/paths.bin"), "mode") == "file" then
        local paths = {binser.readFile(self:vexpath("vexdex/paths.bin"))}
        self.paths = paths[1][1]
    end
    if lfs.attributes(self:vexpath("vexdex/fingerprints.bin"), "mode") == "file" then
        local fingerprints = {binser.readFile(self:vexpath("vexdex/fingerprints.bin"))}
        self.fingerprints = fingerprints[1][1]
    end
    if lfs.attributes(self:vexpath("vexdex/mtimes.bin"), "mode") == "file" then
        local mtimes = {binser.readFile(self:vexpath("vexdex/mtimes.bin"))}
        self.mtimes = mtimes[1][1]
    end
    return self 
end

local function data(task)
    local plain = func.map(task, function(value) return value end)
    plain.vexbody = nil
    return plain
end

function VexDex:writeindex()
    self:atomic(self:vexpath("vexdex/index.bin"), function(path)
        binser.writeFile(path, func.map(self.index, data))
    end)
    self:atomic(self:vexpath("vexdex/index.lua"), function(path)
        pretty.write(path, func.map(self.index, data))
    end)
    self:atomic(self:vexpath("vexdex/backlinks.bin"), function(path)
        binser.writeFile(path, self.backlinks)
    end)
    self:atomic(self:vexpath("vexdex/backlinks.lua"), function(path)
        pretty.write(path, self.backlinks)
    end)
    self:atomic(self:vexpath("vexdex/paths.bin"), function(path)
        binser.writeFile(path, self.paths)
    end)
    self:atomic(self:vexpath("vexdex/paths.lua"), function(path)
        pretty.write(path, self.paths)
    end)
    self:atomic(self:vexpath("vexdex/fingerprints.bin"), function(path)
        binser.writeFile(path, self.fingerprints)
    end)
    self:atomic(self:vexpath("vexdex/fingerprints.lua"), function(path)
        pretty.write(path, self.fingerprints)
    end)
    self:atomic(self:vexpath("vexdex/mtimes.bin"), function(path)
        binser.writeFile(path, self.mtimes)
    end)
    self:atomic(self:vexpath("vexdex/mtimes.lua"), function(path)
        pretty.write(path, self.mtimes)
    end)
    self.dirty = false
    return self 
end

function VexDex:ensureindex()
    if lfs.attributes(self:vexpath("vexdex"), "mode") ~= "directory" then
        lfs.mkdir(self:vexpath("vexdex"))
    end
    local path = self:vexpath("vexdex/index.bin")
    if lfs.attributes(path, "mode") ~= "file" then
        self.index = {}
        self:writeindex()
    else
        self:readindex()
    end
    return self
end

function VexDex:readfocus()
    local path = self:vexpath("vexdex/focus.bin")
    if lfs.attributes(path, "mode") ~= "file" then 
        cli:throw("no-focus", "A focus cannot be found at path " .. tostring(path))
    end 
    local results = {binser.readFile(path)}
    self.focus = results[1][1]
    return self 
end

function VexDex:writefocus()
    self:atomic(self:vexpath("vexdex/focus.bin"), function(path)
        binser.writeFile(path, self.focus)
    end)
    self:atomic(self:vexpath("vexdex/focus.lua"), function(path)
        pretty.write(path, self.focus)
    end)
    return self 
end

function VexDex:log(file, line)
    local f = assert(io.open(self:vexpath("vexdex/" .. file), "a"))
    f:write(line, "\n")
    f:close()
    return self
end

function VexDex:trimlog(file, limit)
    local path = self:vexpath("vexdex/" .. file)
    if lfs.attributes(path, "mode") ~= "file" then return self end
    local lines = {}
    for line in io.lines(path) do table.insert(lines, line) end
    if #lines <= limit then return self end
    self:atomic(path, function(tmp)
        local f = assert(io.open(tmp, "w"))
        f:write(table.concat(func.last(lines, limit), "\n"), "\n")
        f:close()
    end)
    return self
end

function VexDex:atomic(path, func)
    local id = tostring(os.time()) .. tostring(math.random(1000))
    local vexpath = self:vexpath("tmp/" .. id .. '.txt')
    local ok, res = pcall(func, vexpath)
    if not ok then 
        cli:throw('write', path, vexpath)
    end 
    if package.config:sub(1,1) == '\\' then 
        os.remove(path) -- on windows, need to remove the file first
    end
    if not os.rename(vexpath, path) then
        cli:throw('write', path, vexpath)
    end
    if self.listed then self.listed[path] = nil end
    return res
end

-- only need one
local vexdex = VexDex.new()

event:register('*', 'vexdex', function(name, ...)
    local limit = require('core.config').loglimit or 1000
    local time = os.date("%Y-%m-%d %H:%M:%S")
    vexdex:log("event-log.txt", time .. "\t" .. name .. "\t" .. pretty.table({...}):gsub("\n%s*", " "))
    local args = ...
    if name:match("^post%-verb%-") and vexdex.dirty then vexdex:writeindex() end
    if name:match("^pre%-verb%-") and args.raw then
        vexdex:log("verb-log.txt", time .. "\t" .. args.raw)
        vexdex:trimlog("verb-log.txt", limit):trimlog("event-log.txt", limit)
    end
end)

return vexdex
