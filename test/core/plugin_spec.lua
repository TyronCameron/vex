-- Test file for core/plugin.lua
local busted = require 'busted'
local plugin = require 'lib.plugin'

describe("Plugin", function()
  it("should create a new plugin manager", function()
    local plugin_manager = plugin.new()
    assert.truthy(plugin_manager)
    assert.is_table(plugin_manager)
  end)

  it("should register plugins", function()
    local plugin_manager = plugin.new()
    plugin_manager:add("canonicalvexid")
    assert.truthy(plugin_manager.plugins.canonicalvexid)
  end)

  it("should register plugin sets", function()
    local plugin_manager = plugin.new()
    plugin_manager:addenum("tagger", {"canonicalvexid"})
    assert.truthy(plugin_manager.sets.tagger)
    assert.is_table(plugin_manager.sets.tagger.members)
    assert.is_string(plugin_manager.sets.tagger.active)
  end)

  it("should enable plugins", function()
    local plugin_manager = plugin.new()
    plugin_manager:add("canonicalvexid")
    plugin_manager:enable("canonicalvexid")
    assert.is_nil(plugin_manager.disabled.canonicalvexid)
  end)

  it("should disable plugins", function()
    local plugin_manager = plugin.new()
    plugin_manager:add("canonicalvexid")
    plugin_manager:disable("canonicalvexid")
    assert.truthy(plugin_manager.disabled.canonicalvexid)
  end)

  it("should get plugin modules", function()
    local plugin_manager = plugin.new()
    plugin_manager:addenum("tagger", {"canonicalvexid"})
    local tagger = plugin_manager:get("tagger")
    assert.truthy(tagger)
  end)

  it("should reload plugins", function()
    local plugin_manager = plugin.new()
    plugin_manager:addenum("tagger", {"canonicalvexid"})
    local tagger1 = plugin_manager:get("tagger")
    local tagger2 = plugin_manager:reload("tagger")
    assert.truthy(tagger1)
    assert.truthy(tagger2)
  end)

  it("should select plugin set members", function()
    local plugin_manager = plugin.new()
    plugin_manager:addenum("tagger", {"canonicalvexid", "csvdata"})
    plugin_manager:select("tagger", "csvdata")
    assert.equal(plugin_manager.sets.tagger.active, "csvdata")
  end)

  it("should iterate enabled plugins", function()
    local plugin_manager = plugin.new()
    plugin_manager:addenum("tagger", {"canonicalvexid"})
    local count = 0
    plugin_manager:each(function(name, mod)
      count = count + 1
    end)
    assert.is_number(count)
  end)
end)