-- Test file for lib/func.lua
local busted = require 'busted'
local func = require 'lib.func'

describe("func", function()

    -- ==================== imap ====================

    it("`func.imap` maps values over an indexed table", function()
        local result = func.imap({1, 2, 3}, function(v) return v * 2 end)
        assert.equal(3, #result)
        assert.equal(2, result[1])
        assert.equal(4, result[2])
        assert.equal(6, result[3])
    end)

    it("`func.imap` passes the index as second argument", function()
        local result = func.imap({"a", "b", "c"}, function(v, i) return i end)
        assert.equal(1, result[1])
        assert.equal(2, result[2])
        assert.equal(3, result[3])
    end)

    -- ==================== ifilter ====================

    it("`func.ifilter` keeps elements where predicate is true", function()
        local result = func.ifilter({1, 2, 3, 4, 5}, function(v) return v % 2 == 0 end)
        assert.equal(2, #result)
        assert.equal(2, result[1])
        assert.equal(4, result[2])
    end)

    it("`func.ifilter` returns an empty table when nothing matches", function()
        local result = func.ifilter({1, 3, 5}, function(v) return v % 2 == 0 end)
        assert.equal(0, #result)
    end)

    -- ==================== ifold ====================

    it("`func.ifold` reduces with an initial value", function()
        local result = func.ifold({1, 2, 3, 4}, function(acc, v) return acc + v end, 0)
        assert.equal(10, result)
    end)

    it("`func.ifold` uses first element as seed when no init given", function()
        local result = func.ifold({1, 2, 3, 4}, function(acc, v) return acc + v end)
        assert.equal(10, result)
    end)

    it("`func.ifold` with init differs from no-init for single element", function()
        assert.equal(5,  func.ifold({5}, function(a, b) return a + b end))
        assert.equal(15, func.ifold({5}, function(a, b) return a + b end, 10))
    end)

    -- ==================== keys / values ====================

    it("`func.keys` returns all keys of a table", function()
        local result = func.keys({a = 1, b = 2, c = 3})
        assert.equal(3, #result)
    end)

    it("`func.values` returns all values of a table", function()
        local result = func.values({a = 1, b = 2, c = 3})
        assert.equal(3, #result)
    end)

    -- ==================== imerge ====================

    it("`func.imerge` concatenates two arrays", function()
        local result = func.imerge({1, 2}, {3, 4})
        assert.equal(4, #result)
        assert.equal(1, result[1])
        assert.equal(2, result[2])
        assert.equal(3, result[3])
        assert.equal(4, result[4])
    end)

    -- ==================== reverse ====================

    it("`func.reverse` reverses an array", function()
        local result = func.reverse({1, 2, 3})
        assert.equal(3, result[1])
        assert.equal(2, result[2])
        assert.equal(1, result[3])
    end)

    -- ==================== range ====================

    it("`func.range` generates integers from 1 to n", function()
        local result = func.range(5)
        assert.equal(5, #result)
        assert.equal(1, result[1])
        assert.equal(5, result[5])
    end)

    it("`func.range` generates integers from start to end", function()
        local result = func.range(3, 6)
        assert.equal(4, #result)
        assert.equal(3, result[1])
        assert.equal(6, result[4])
    end)

    it("`func.range` returns empty table when end < start", function()
        local result = func.range(5, 3)
        assert.equal(0, #result)
    end)

    -- ==================== slice ====================

    it("`func.slice` returns a sub-array between two indices", function()
        local result = func.slice({1, 2, 3, 4, 5}, 2, 4)
        assert.equal(3, #result)
        assert.equal(2, result[1])
        assert.equal(3, result[2])
        assert.equal(4, result[3])
    end)

    it("`func.slice` returns empty table when end < start", function()
        local result = func.slice({1, 2, 3}, 3, 1)
        assert.equal(0, #result)
    end)

    -- ==================== first ====================

    it("`func.first` returns the first n elements", function()
        local result = func.first({1, 2, 3, 4, 5}, 3)
        assert.equal(3, #result)
        assert.equal(1, result[1])
        assert.equal(3, result[3])
    end)

    it("`func.first` defaults to 1 element", function()
        local result = func.first({10, 20, 30})
        assert.equal(1, #result)
        assert.equal(10, result[1])
    end)

    -- ==================== rep ====================

    it("`func.rep` repeats a table n times", function()
        local result = func.rep({1, 2}, 3)
        assert.equal(6, #result)
        assert.equal(1, result[1])
        assert.equal(2, result[2])
        assert.equal(1, result[3])
    end)

    it("`func.rep` repeats a scalar value n times", function()
        local result = func.rep(7, 4)
        assert.equal(4, #result)
        assert.equal(7, result[1])
        assert.equal(7, result[4])
    end)

    -- ==================== isempty ====================

    it("`func.isempty` returns true for an empty table", function()
        assert.truthy(func.isempty({}))
    end)

    it("`func.isempty` returns false for a non-empty table", function()
        assert.falsy(func.isempty({1}))
    end)

end)
