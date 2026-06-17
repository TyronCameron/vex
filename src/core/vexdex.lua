
local lfs = require "lib.lfs"
local cli = require "lib.cli"
local pretty = require 'lib.pretty'
local binser = require 'lib.binser'
local lfsext = require 'lib.lfsext'

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
        modified = os.time(),
        index = {}
    }, VexDex)
    return this:ensureindex()
end

function VexDex:unsafe_add(vexid, storage)
    self.index[vexid] = storage
    return self
end

function VexDex:add(vexid, storage)
    self:unsafe_add(vexid, storage)
    return self:writeindex()
end

function VexDex:unsafe_remove(vexid)
    self.index[vexid] = nil
    return self
end

function VexDex:remove(vexid)
    self:unsafe_remove(vexid)
    return self:writeindex()
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
    return self 
end

function VexDex:writeindex()
    self.modified = os.time()
    self:atomic(self:vexpath("vexdex/index.bin"), function(path)
        binser.writeFile(path, self.index)
    end)
    self:atomic(self:vexpath("vexdex/index.lua"), function(path)
        pretty.write(path, self.index)
    end)
    return self 
end

function VexDex:ensureindex()
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
    os.rename(vexpath, path)
    return res
end

-- only need one
return VexDex.new()
