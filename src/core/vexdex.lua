
local lfs = require "lib.lfs"
local cli = require "lib.cli"
local pretty = require 'lib.pretty'
local binser = require 'lib.binser'

local VexDex = {}
VexDex.__index = VexDex

local default_config = {
    taskfolder = '.',
    default = {
        taskformat = 'obsidian',
        view = 'table',
        dataformat = 'csv',
        option = 'prev',
        tasktype = 'task'
    }, 
    plugins = {
        vexations = true,
        inline = true
    }
}

local function rootdir(path)
    local current = path
    while current do
        if lfs.attributes(current .. "/.vex", "mode") == "directory" then
            return current
        end
        local parent = current:match("(.+)[\\/][^\\/]+$")
        if parent == current then
            break
        end
        current = parent
    end
    return nil
end

local function setup_vex_dir(path)
    path = path or lfs.currentdir()
    p = rootdir(path) 
    if p then
        cli:throw("already-vexed")
    end
    local ok, err = lfs.mkdir(path .. "/.vex")
    if not ok then
        cli:throw("bug", "Failed to create .vex directory: " .. tostring(err))
    end
    return path .. "/.vex"
end 

local function create_config(path)
    local f = io.open(path .. "/config.lua", "w")
    local str = "return " .. pretty.table(default_config)
    f:write(str)
    f:close()
end 

local function create_ext_folders(path)
    lfs.mkdir(path .. "/vexdex")
    lfs.mkdir(path .. "/optics")
    lfs.mkdir(path .. "/views")
    lfs.mkdir(path .. "/events")
    lfs.mkdir(path .. "/tasks")
    lfs.mkdir(path .. "/recipes")
end 

function VexDex.init(path)
    vexpath = setup_vex_dir(path)
    create_config(vexpath)
    create_ext_folders(vexpath)
end

function VexDex.new(path)
    path = path or lfs.currentdir()
    local found = rootdir(path)
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
    binser.writeFile(self:vexpath("vexdex/index.bin"), self.index)
    pretty.write(self:vexpath("vexdex/index.lua"), self.index)
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
    binser.writeFile(self:vexpath("vexdex/focus.bin"), self.focus)
    pretty.write(self:vexpath("vexdex/focus.lua"), self.focus)
    return self 
end

return VexDex