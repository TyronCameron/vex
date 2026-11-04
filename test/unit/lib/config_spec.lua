-- Test file for lib/config.lua
local busted = require 'busted'
local Config = require 'lib.config'

describe("Config", function()

    it("loads a config file and exposes its values as properties", function()
        local tmpfile = os.tmpname()
        local f = io.open(tmpfile, "w")
        f:write("return { greeting = 'hello', count = 42 }")
        f:close()

        local cfg = Config.new()
        cfg:registerpath(tmpfile)
        cfg:loadall()

        assert.equal("hello", cfg.greeting)
        assert.equal(42, cfg.count)

        os.remove(tmpfile)
    end)

    it("exposes settings that share a name with the config's own fields", function()
        local tmpfile = os.tmpname()
        local f = io.open(tmpfile, "w")
        f:write("return { paths = { groupby = {'status'} } }")
        f:close()

        local cfg = Config.new():registerpath(tmpfile):loadall()

        assert.same({groupby = {'status'}}, cfg.paths)

        os.remove(tmpfile)
    end)

    it("later config files override earlier ones", function()
        local first  = os.tmpname()
        local second = os.tmpname()

        local f1 = io.open(first,  "w"); f1:write("return { key = 'first'  }"); f1:close()
        local f2 = io.open(second, "w"); f2:write("return { key = 'second' }"); f2:close()

        local cfg = Config.new()
        cfg:registerpath(first):registerpath(second):loadall()

        assert.equal("second", cfg.key)

        os.remove(first)
        os.remove(second)
    end)

    it("silently skips missing config files", function()
        local cfg = Config.new()
        cfg:registerpath("/does/not/exist.lua")
        assert.has_no.errors(function() cfg:loadall() end)
    end)

    it("ignores a path that is nil", function()
        local cfg = Config.new():registerpath(nil)
        assert.same({}, cfg.files)
    end)

    local function configfile(code)
        local path = os.tmpname()
        local f = io.open(path, "w")
        f:write(code)
        f:close()
        return path
    end

    it("merges maps from later files into earlier ones and replaces lists", function()
        local first = configfile("return { paths = { groupby = {'status'}, other = 1 }, taskowners = {'a', 'b'} }")
        local second = configfile("return { paths = { groupby = {} }, taskowners = {'c'} }")
        local cfg = Config.new():registerpath(first):registerpath(second):loadall()
        assert.same({groupby = {}, other = 1}, cfg.paths)
        assert.same({'c'}, cfg.taskowners)
        os.remove(first)
        os.remove(second)
    end)

    it("starts from the defaults it is given and lets files override them", function()
        local defaults = {loglimit = 100, fingerprint = {exclude = {'modified'}, extra = true}}
        local path = configfile("return { fingerprint = { exclude = {} } }")
        local cfg = Config.new(defaults):registerpath(path):loadall()
        assert.equal(100, cfg.loglimit)
        assert.same({exclude = {}, extra = true}, cfg.fingerprint)
        assert.same({exclude = {'modified'}, extra = true}, defaults.fingerprint)
        os.remove(path)
    end)

    it("reports a file that does not run instead of carrying on", function()
        local path = configfile("return {")
        local cfg, failed, err = Config.new():registerpath(path):loadall()
        assert.is_nil(cfg)
        assert.equal(path, failed)
        assert.truthy(err)
        os.remove(path)
    end)

    it("reports a file that does not return a table", function()
        local path = configfile("return 5")
        local cfg, failed = Config.new():registerpath(path):loadall()
        assert.is_nil(cfg)
        assert.equal(path, failed)
        os.remove(path)
    end)

    it("merges two tables without changing either", function()
        local base = {a = {b = 1, c = 2}, list = {1, 2}}
        local over = {a = {b = 3}, list = {9}}
        assert.same({a = {b = 3, c = 2}, list = {9}}, Config.merge(base, over))
        assert.same({a = {b = 1, c = 2}, list = {1, 2}}, base)
        assert.same({a = {b = 3}, list = {9}}, over)
    end)

end)
