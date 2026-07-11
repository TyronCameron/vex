-- Test file for core/recipe.lua
local busted = require 'busted'
local Recipe = require 'core.recipe'

describe("Recipe", function()

    it("creates a new recipe manager", function()
        local r = Recipe.new(nil)
        assert.truthy(r)
        assert.is_table(r.recipes)
    end)

    it("registers a recipe by name", function()
        local r = Recipe.new(nil)
        r:recipe("mytask") {
            add = function(taskmanager, props) return props end
        }
        assert.truthy(r.recipes["mytask"])
        assert.is_function(r.recipes["mytask"].add)
    end)

    it("recipe add function receives the taskmanager and properties", function()
        local fake_tm = {}
        local r = Recipe.new(fake_tm)
        local captured = {}
        r:recipe("capture") {
            add = function(tm, props)
                captured.tm = tm
                captured.props = props
            end
        }
        r.recipes["capture"].add(fake_tm, {name = "test"})
        assert.equal(fake_tm, captured.tm)
        assert.equal("test", captured.props.name)
    end)

    it("can register multiple distinct recipes", function()
        local r = Recipe.new(nil)
        r:recipe("alpha") { add = function() return "alpha" end }
        r:recipe("beta")  { add = function() return "beta"  end }
        assert.truthy(r.recipes["alpha"])
        assert.truthy(r.recipes["beta"])
        assert.equal("alpha", r.recipes["alpha"].add())
        assert.equal("beta",  r.recipes["beta"].add())
    end)

end)
