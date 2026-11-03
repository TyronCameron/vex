
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
        logs = {},
        dirty = false
    }, VexDex)
    return this:ensureindex()
end

local function excluded()
    return (require('core.config').fingerprint or {}).exclude or {}
end

function VexDex:unsafe_add(vexid, task)
    self.index[vexid] = task
    self.fingerprints[vexid] = {whole = self:fingerprint(task), content = self:fingerprint(task, excluded())}
    self.dirty = true
    return self
end

function VexDex:add(vexid, storage)
    self:unsafe_add(vexid, storage)
    return self:writeindex()
end

function VexDex:unsafe_remove(vexid, previous)
    self.index[vexid] = nil
    self.backlinks[vexid] = nil
    self.paths[vexid] = nil
    self.fingerprints[vexid] = nil
    self.mtimes[vexid] = nil
    self.dirty = true
    return self:unsafe_link(vexid, {}, previous)
end

function VexDex:remove(vexid, previous)
    self:unsafe_remove(vexid, previous)
    return self:writeindex()
end

function VexDex:linksto(vexid)
    local sources = func.keys(self.backlinks[vexid] or {})
    table.sort(sources)
    return sources
end

function VexDex:unsafe_link(vexid, links, previous)
    self.dirty = true
    for _, target in ipairs(previous or {}) do
        local sources = self.backlinks[target]
        if sources then
            sources[vexid] = nil
            if next(sources) == nil then self.backlinks[target] = nil end
        end
    end
    for _, target in ipairs(links) do
        self.backlinks[target] = self.backlinks[target] or {}
        self.backlinks[target][vexid] = true
    end
    return self
end

function VexDex:link(vexid, links, previous)
    self:unsafe_link(vexid, links, previous)
    return self:writeindex()
end

function VexDex:unsafe_locate(vexid, path)
    if self.paths[vexid] ~= path then self.dirty = true end
    self.paths[vexid] = path
    return self
end

-- records the mtime of a task's file as vex last saw it
function VexDex:unsafe_stamp(vexid, path)
    self.listed = self.listed or lfsext.mtimes(self:taskroot())
    local mtime = self.listed[path] or lfsext.mtime(path)
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

-- a hash of a task, leaving out the given fields
function VexDex:fingerprint(task, exclude)
    local plain = func.map(task, function(value) return value end)
    for _, field in ipairs(exclude or {}) do plain[field] = nil end
    return hash.fnv1a(pretty.table(plain))
end

-- whether a task differs from the one last indexed under its vexid, and whether it does outside the fields config.fingerprint.exclude names; a task never indexed differs in both
function VexDex:changed(vexid, task)
    local kept = self.fingerprints[vexid] or {}
    return kept.whole ~= self:fingerprint(task), kept.content ~= self:fingerprint(task, excluded())
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
    self:atomic(self:vexpath("vexdex/backlinks.bin"), function(path)
        binser.writeFile(path, self.backlinks)
    end)
    self:atomic(self:vexpath("vexdex/paths.bin"), function(path)
        binser.writeFile(path, self.paths)
    end)
    self:atomic(self:vexpath("vexdex/fingerprints.bin"), function(path)
        binser.writeFile(path, self.fingerprints)
    end)
    self:atomic(self:vexpath("vexdex/mtimes.bin"), function(path)
        binser.writeFile(path, self.mtimes)
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
    return self 
end

function VexDex:log(file, line)
    local f = self.logs[file]
    if not f then
        f = assert(io.open(self:vexpath("vexdex/" .. file), "a"))
        f:setvbuf("line")
        self.logs[file] = f
    end
    f:write(line, "\n")
    return self
end

function VexDex:closelog(file)
    if self.logs[file] then
        self.logs[file]:close()
        self.logs[file] = nil
    end
    return self
end

function VexDex:trimlog(file, limit)
    self:closelog(file)
    local path = self:vexpath("vexdex/" .. file)
    if lfs.attributes(path, "mode") ~= "file" then return self end
    local f = assert(io.open(path, "rb"))
    local text = f:read("*a")
    f:close()
    local newlines = 0
    for i = #text, 1, -1 do
        if text:byte(i) == 10 then
            newlines = newlines + 1
            if newlines > limit then
                self:atomic(path, function(tmp)
                    local out = assert(io.open(tmp, "wb"))
                    out:write(text:sub(i + 1))
                    out:close()
                end)
                break
            end
        end
    end
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

local function brief(value)
    local text = type(value) == 'table' and (rawget(value, 'raw') or '<table>') or tostring(value)
    if #text > 200 then return text:sub(1, 200) .. '...' end
    return text
end

event:register('*', 'vexdex', function(name, ...)
    local limit = require('core.config').loglimit or 100
    local time = os.date("%Y-%m-%d %H:%M:%S")
    local args = {...}
    local shown = {}
    for i = 1, select('#', ...) do shown[i] = brief(args[i]) end
    vexdex:log("event-log.txt", time .. "\t" .. name .. "\t" .. table.concat(shown, " "):gsub("\n%s*", " "))
    local first = args[1]
    if name:match("^post%-verb%-") then
        if vexdex.dirty then vexdex:writeindex() end
        vexdex:trimlog("event-log.txt", limit)
    end
    if name:match("^pre%-verb%-") and type(first) == "table" and first.raw then
        vexdex:log("verb-log.txt", time .. "\t" .. first.raw)
        vexdex:trimlog("verb-log.txt", limit):trimlog("event-log.txt", limit)
    end
end)

return vexdex
