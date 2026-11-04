local function source_dir()
    for template in package.path:gmatch("[^;]+") do
        local path = template:gsub("%?", "lib/plugin")
        local file = io.open(path)
        if file then
            file:close()
            return path:match("^(.+)[\\/]lib[\\/]plugin%.lua$")
        end
    end
end

local script_dir = source_dir() .. "/"
local lfs = require 'lib.lfs'
local lfsext = require 'lib.lfsext'
local layers = lfsext.layers()
for _, layer in ipairs(layers) do
    package.path = layer .. "/?.lua;" .. package.path
end

math.randomseed(os.time())

local plugin = require 'lib.plugin'
plugin:addenum("tagger", {"canonicalvexid"})
plugin:addenum("taskpath", {"grouppath"})
plugin:addenum("taskformat", {"obsidian"})
plugin:addenum("sortdata", {"canonicalsort"})
plugin:addenum("frontmatter", {"canonicalfrontmatter"})
plugin:addenum("body", {"canonicalbody"})
plugin:addall(script_dir .. 'plugin')
for _, layer in ipairs(layers) do
    if lfs.attributes(layer .. '/plugin', 'mode') == 'directory' then plugin:addall(layer .. '/plugin') end
end

local cli = require 'lib.cli'

cli:verb "init" {
    function(args)
        if #args > 0 then cli:throw('usage', 'You cannot provide args to vex init') end
        require('core.init')()
    end,
    doc = "Initialise a new vex directory by setting up a `.vex` folder",
    args = "",
    example = "vex init"
}

cli:verb "version" {
    function() print(require 'version') end,
    doc = "Print the installed vex version",
    args = "",
    example = "vex version"
}

require 'core.errors'

if arg[1] ~= 'init' and arg[1] ~= 'version' then
    local config = require 'core.config'
    local configured, name, problem = plugin:configure(config.plugins or {})
    if not configured then cli:throw('bad-plugin-setting', name, problem) end
    require 'core.verbs'
    plugin:each(function(plug) end) -- automatically loads them
    require 'core.extensions'
end

cli:run(cli:rawify(arg))
