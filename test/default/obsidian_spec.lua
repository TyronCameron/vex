-- Test file for default/obsidian.lua using busted
local busted = require 'busted'
local obsidian = require 'default.obsidian'

describe("Obsidian", function()
  context("A nested context", function()
    it("A test", function()
      assert.not_equal("ham", "cheese")
    end)
    context("Another nested context", function()
      it("Another test", function()
        assert.is_true(2 > 1)
      end)
    end)
  end)
  it("A test in the top-level context", function()
    -- This test should pass now
    assert.is_true(true)
  end)
end)