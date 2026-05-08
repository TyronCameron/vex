local script_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = script_dir .. "?.lua;" .. script_dir .. "?/init.lua;" .. package.path
-- package.cpath = script_dir .. "?.dll;"  .. script_dir .. "?.so;"       .. package.cpath

local plugin = require 'lib.plugin'
plugin:addenum("tagger", {"canonicalvexid"})
plugin:addenum("taskpath", {"flatpath"})
plugin:addenum("taskformat", {"obsidian"})
plugin:addenum("dataformat", {"csvdata"})
plugin:addenum("sortdata", {"canonicalsort"})
plugin:addenum("frontmatter", {"canonicalfrontmatter"})
plugin:addenum("body", {"canonicalbody"})

local cli = require 'lib.cli'

require 'core.errors'
require 'core.verbs'

cli:run(table.concat(arg, " "))
