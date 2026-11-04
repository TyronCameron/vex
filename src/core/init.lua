local pretty = require 'lib.pretty'
local lfs = require "lib.lfs"
local cli = require "lib.cli"
local Config = require "lib.config"
local defaults = require "core.configdefaults"

local default_config = Config.merge(defaults, {paths = {groupby = {"status", "lineage"}}})

local function setup_vex_dir(path)
    path = path or lfs.currentdir()
    if lfs.attributes(path .. "/.vex", "mode") == "directory" then
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
    lfs.mkdir(path .. "/focuses")
    lfs.mkdir(path .. "/views")
    lfs.mkdir(path .. "/tasks")
    lfs.mkdir(path .. "/recipes")
    lfs.mkdir(path .. "/tmp")
    lfs.mkdir(path .. "/events")
    lfs.mkdir(path .. "/plugin")
end 

local function init(path)
    local vexpath = setup_vex_dir(path)
    create_config(vexpath)
    create_ext_folders(vexpath)
end

return init 