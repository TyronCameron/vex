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

end)
