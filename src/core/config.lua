local cfg = require 'lib.config'
local lfs = require 'lib.lfs'
local lfsext = require 'lib.lfsext'
local vexdex = require 'core.vexdex'

local config = cfg.new()
local globaldir = lfsext.globaldir()
if globaldir and lfs.attributes(globaldir .. '/config.lua', 'mode') == 'file' then
    config:registerpath(globaldir .. '/config.lua')
end
return config:registerpath(vexdex:vexpath('config.lua')):loadall()