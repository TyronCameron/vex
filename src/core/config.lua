local Config = require 'lib.config'
local cli = require 'lib.cli'
local lfs = require 'lib.lfs'
local lfsext = require 'lib.lfsext'
local schema = require 'lib.schema'
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

if not lfsext.rootdir(lfs.currentdir()) then cli:throw('not-vexed') end

local config = Config.new(defaults)
for _, dir in ipairs(lfsext.layers()) do config:registerpath(dir .. '/config.lua') end

local loaded, path, err = config:loadall()
if not loaded then cli:throw('bad-config-file', path, err) end

local ok, normalised = pcall(specification.prevalidate, specification, config.properties)
if not ok then cli:throw('bad-config', normalised) end
local valid, failure = specification:validate(normalised)
if not valid then cli:throw('bad-config', failure) end
config.properties = normalised

return config
