local func = require 'lib.func'
local lfs = require 'lib.lfs'
local lfsext = require 'lib.lfsext'
local cli = require 'lib.cli'
local vexdex = require 'core.vexdex'

local env = setmetatable({
    task = require 'core.task',
    recipe = require 'core.recipe',
    focus = require 'core.focus',
    view = require 'core.view',
    schema = require 'lib.schema',
    event = require 'lib.event',
}, {__index = _G})

local function scripts(dir)
    if lfs.attributes(dir, 'mode') ~= 'directory' then return {} end
    local paths = func.ifilter(lfsext.walk(dir), function(path) return path:match('%.lua$') end)
    table.sort(paths)
    return paths
end

local globaldir = lfsext.globaldir()

for _, folder in ipairs {'tasks', 'recipes', 'focuses', 'views', 'events'} do
    local dirs = {vexdex:vexpath(folder)}
    if globaldir then table.insert(dirs, 1, globaldir .. '/' .. folder) end
    for _, dir in ipairs(dirs) do
        for _, path in ipairs(scripts(dir)) do
            local ok, err = pcall(function() setfenv(assert(loadfile(path)), env)() end)
            if not ok then cli:throw('bad-extension', path, err) end
        end
    end
end
