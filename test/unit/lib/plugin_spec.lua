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

end)
