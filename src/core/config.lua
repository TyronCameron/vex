local cfg = require 'lib.config'
local vexdex = require 'core.vexdex'
return cfg.new():registerpath(vexdex:vexpath('config.lua')):loadall()