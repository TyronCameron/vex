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

end)
