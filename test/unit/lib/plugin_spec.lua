local plugin = require 'lib.plugin'

describe("Plugin", function()

    it("resolves a set to its active member, falling back to the default implementation", function()
        local plugins = plugin.new():addenum("tagger", {"canonicalvexid"})
        assert.equal(require 'default.canonicalvexid', plugins:get("tagger"))
    end)

    it("prefers a plugin over the default implementation of the same name", function()
        package.preload["plugin.__specplugin"] = function() return "plugin" end
        package.preload["default.__specplugin"] = function() return "default" end
        assert.equal("plugin", plugin.new():add("__specplugin"):get("__specplugin"))
    end)

    it("switches the active member with select", function()
        local plugins = plugin.new():addenum("tagger", {"canonicalvexid", "canonicalsort"})
        plugins:select("tagger", "canonicalsort")
        assert.equal(require 'default.canonicalsort', plugins:get("tagger"))
    end)

    it("skips disabled plugins until they are enabled again", function()
        local plugins = plugin.new():add("canonicalsort"):disable("canonicalsort")
        local seen = {}
        plugins:each(function(name) seen[name] = true end)
        assert.is_nil(plugins:get("canonicalsort"))
        assert.is_nil(seen.canonicalsort)
        plugins:enable("canonicalsort")
        assert.equal(require 'default.canonicalsort', plugins:get("canonicalsort"))
    end)

    it("does not register a folder's file again when its name is already a plugin or a set member", function()
        local dir = os.tmpname()
        os.remove(dir)
        os.execute("mkdir -p '" .. dir .. "' && touch '" .. dir .. "/canonicalvexid.lua' '" .. dir .. "/extra.lua'")
        local plugins = plugin.new():addenum("tagger", {"canonicalvexid"}):addall(dir)
        os.execute("rm -rf '" .. dir .. "'")
        assert.same({"canonicalvexid", "extra"}, (function()
            local names = {}
            for name in pairs(plugins.plugins) do table.insert(names, name) end
            table.sort(names)
            return names
        end)())
    end)

    describe("select", function()
        it("accepts any registered plugin, not only the listed members", function()
            package.preload["plugin.__specmember"] = function() return "member" end
            local plugins = plugin.new():addenum("tagger", {"canonicalvexid"}):add("__specmember")
            plugins:select("tagger", "__specmember")
            assert.equal("member", plugins:get("tagger"))
        end)

        it("refuses a plugin that is not registered", function()
            local plugins = plugin.new():addenum("tagger", {"canonicalvexid"})
            assert.has.errors(function() plugins:select("tagger", "nosuch") end)
        end)
    end)

    describe("configure", function()
        local function plugins()
            package.preload["plugin.__specmember"] = function() return "member" end
            package.preload["plugin.extra"] = function() return "extra" end
            return plugin.new():addenum("tagger", {"canonicalvexid"}):add("__specmember"):add("extra")
        end

        it("selects a slot's member and switches a standalone plugin off and on", function()
            local p = plugins()
            assert.equal(p, p:configure {tagger = "__specmember", extra = false})
            assert.equal("member", p:get("tagger"))
            assert.is_nil(p:get("extra"))
            p:configure {extra = true}
            assert.truthy(p:get("extra"))
        end)

        it("names the first unknown plugin or slot", function()
            local p, name, problem = plugins():configure {nosuch = false}
            assert.is_nil(p)
            assert.equal("nosuch", name)
            assert.truthy(problem:find("unknown", 1, true))
        end)

        it("names a slot given a plugin that is not registered", function()
            local p, name, problem = plugins():configure {tagger = "nosuch"}
            assert.is_nil(p)
            assert.equal("tagger", name)
            assert.truthy(problem:find("nosuch", 1, true))
        end)

        it("refuses a value of the wrong kind", function()
            local p, name = plugins():configure {tagger = false}
            assert.is_nil(p)
            assert.equal("tagger", name)
            p, name = plugins():configure {extra = "yes"}
            assert.is_nil(p)
            assert.equal("extra", name)
        end)

        it("refuses to switch off a plugin that fills a slot", function()
            local p, name = plugins():configure {canonicalvexid = false}
            assert.is_nil(p)
            assert.equal("canonicalvexid", name)
        end)
    end)

end)
