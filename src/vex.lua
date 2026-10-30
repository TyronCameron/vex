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
local lfsext = require 'lib.lfsext'
local globaldir = lfsext.globaldir()
if globaldir then
    package.path = globaldir .. "/?.lua;" .. package.path
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
local globalplugins = lfsext.globalpath('plugin')
if globalplugins then plugin:addall(globalplugins) end

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
    require 'core.verbs'
    plugin:each(function(plug) end) -- automatically loads them
end

cli:run(cli:rawify(arg))
