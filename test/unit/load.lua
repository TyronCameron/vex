local script_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
local src_dir = script_dir .. "../../src/"
package.path = src_dir .. "?.lua;" .. src_dir .. "?/init.lua;" .. package.path
package.cpath = src_dir .. "?.dll;"  .. src_dir .. "?.so;"       .. package.cpath

local plugin = require 'lib.plugin'
plugin:addenum("tagger", {"canonicalvexid"})
plugin:addenum("taskpath", {"flatpath"})
plugin:addenum("taskformat", {"obsidian"})
plugin:addenum("dataformat", {"csvdata"})
plugin:addenum("sortdata", {"canonicalsort"})
plugin:addenum("frontmatter", {"canonicalfrontmatter"})
plugin:addenum("body", {"canonicalbody"})
plugin:addall(src_dir .. '/plugin')

require 'core.errors'
require 'core.verbs'

plugin:each(function(plug) end) -- automatically loads them

