local script_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = script_dir .. "?.lua;" .. script_dir .. "?/init.lua;" .. package.path
-- package.cpath = script_dir .. "?.dll;"  .. script_dir .. "?.so;"       .. package.cpath

local cli = require 'lib.cli'

require 'core.errors'
require 'core.verbs'

cli:run(table.concat(arg, " "))
