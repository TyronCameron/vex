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
        local plugins = plugin.new():addenum("tagger", {"canonicalvexid", "flatpath"})
        plugins:select("tagger", "flatpath")
        assert.equal(require 'default.flatpath', plugins:get("tagger"))
    end)

    it("skips disabled plugins until they are enabled again", function()
        local plugins = plugin.new():add("flatpath"):disable("flatpath")
        local seen = {}
        plugins:each(function(name) seen[name] = true end)
        assert.is_nil(plugins:get("flatpath"))
        assert.is_nil(seen.flatpath)
        plugins:enable("flatpath")
        assert.equal(require 'default.flatpath', plugins:get("flatpath"))
    end)

end)
