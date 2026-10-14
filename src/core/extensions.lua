local func = require 'lib.func'
local lfs = require 'lib.lfs'
local lfsext = require 'lib.lfsext'
local cli = require 'lib.cli'
local vexdex = require 'core.vexdex'

local env = setmetatable({
    task = require 'core.task',
    recipe = require 'core.recipe',
    schema = require 'lib.schema',
}, {__index = _G})

local function scripts(folder)
    local dir = vexdex:vexpath(folder)
    if lfs.attributes(dir, 'mode') ~= 'directory' then return {} end
    local paths = func.ifilter(lfsext.walk(dir), function(path) return path:match('%.lua$') end)
    table.sort(paths)
    return paths
end

for _, folder in ipairs {'tasks', 'recipes'} do
    for _, path in ipairs(scripts(folder)) do
        local ok, err = pcall(function() setfenv(assert(loadfile(path)), env)() end)
        if not ok then cli:throw('bad-extension', path, err) end
    end
end
