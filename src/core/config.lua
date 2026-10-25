local cfg = require 'lib.config'
local lfsext = require 'lib.lfsext'
local vexdex = require 'core.vexdex'
return cfg.new():registerpath(lfsext.globalpath('config.lua')):registerpath(vexdex:vexpath('config.lua')):loadall()