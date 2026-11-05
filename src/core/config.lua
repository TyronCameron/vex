local cfg = require 'lib.config'
local cli = require 'lib.cli'
local lfsext = require 'lib.lfsext'
local schema = require 'lib.schema'
local vexdex = require 'core.vexdex'
local defaults = require 'core.configdefaults'

local specification = schema.atleast {
    taskfolder = schema.path,
    loglimit = schema.all(schema.num, schema.uint),
    taskowners = schema.vec {schema.str},
    default = schema.atleast {tasktype = schema.str},
    fingerprint = schema.atleast {exclude = schema.vec {schema.str}},
    paths = schema.table,
    plugins = schema.maybe {schema.table}
}

local config = cfg.new(defaults):registerpath(lfsext.globalpath('config.lua')):registerpath(vexdex:vexpath('config.lua'))

local loaded, path, err = config:loadall()
if not loaded then cli:throw('bad-config-file', path, err) end

local ok, normalised = pcall(specification.prevalidate, specification, config.properties)
if not ok then cli:throw('bad-config', normalised) end
local valid, failure = specification:validate(normalised)
if not valid then cli:throw('bad-config', failure) end
config.properties = normalised

return config
