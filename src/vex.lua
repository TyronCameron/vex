local script_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = script_dir .. "?.lua;" .. script_dir .. "?/init.lua;" .. package.path
package.cpath = script_dir .. "?.dll;"  .. script_dir .. "?.so;"       .. package.cpath

local plugin = require 'lib.plugin'
plugin:addenum("tagger", {"canonicalvexid"})
plugin:addenum("taskpath", {"flatpath"})
plugin:addenum("taskformat", {"obsidian"})
plugin:addenum("dataformat", {"csvdata"})
plugin:addenum("sortdata", {"canonicalsort"})
plugin:addenum("frontmatter", {"canonicalfrontmatter"})
plugin:addenum("body", {"canonicalbody"})
plugin:addall(script_dir .. '/plugin')

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

require 'core.errors'

if arg[1] ~= 'init' then
    require 'core.verbs'
    plugin:each(function(plug) end) -- automatically loads them
end

cli:run(table.concat(arg, " "))
