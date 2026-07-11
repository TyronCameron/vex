-- Test file for lib/optic.lua
local busted = require 'busted'
local Optic = require 'lib.optic'

describe("Optic", function()

    -- ==================== field ====================

    it("`Optic.field` get returns the value at the given key", function()
        local result = Optic.field("name"):get({name = "alice"})
        assert.equal(1, #result)
        assert.equal("alice", result[1])
    end)

    it("`Optic.field` set updates the value at the given key", function()
        local data = {name = "alice"}
        Optic.field("name"):set(data, function(v) return "bob" end)
        assert.equal("bob", data.name)
    end)

    it("`Optic.field` get returns nothing for a missing key (nil is not inserted)", function()
        local result = Optic.field("missing"):get({name = "alice"})
        assert.equal(0, #result)
    end)

    -- ==================== maybe ====================

    it("`Optic.maybe` get returns the value when the key exists", function()
        local result = Optic.maybe("key"):get({key = "value"})
        assert.equal(1, #result)
        assert.equal("value", result[1])
    end)

    it("`Optic.maybe` get returns nothing when the key is absent", function()
        local result = Optic.maybe("key"):get({})
        assert.equal(0, #result)
    end)

    it("`Optic.maybe` set updates the value when the key exists", function()
        local data = {key = "old"}
        Optic.maybe("key"):set(data, function(v) return "new" end)
        assert.equal("new", data.key)
    end)

    it("`Optic.maybe` set leaves data unchanged when the key is absent", function()
        local data = {other = "x"}
        Optic.maybe("key"):set(data, function(v) return "new" end)
        assert.is_nil(data.key)
    end)

    -- ==================== iso ====================

    it("`Optic.iso` get applies the forward transformation", function()
        local double = Optic.iso(function(x) return x * 2 end, function(x) return x / 2 end)
        local result = double:get(5)
        assert.equal(1, #result)
        assert.equal(10, result[1])
    end)

    it("`Optic.iso` set applies the backward transformation", function()
        local double = Optic.iso(function(x) return x * 2 end, function(x) return x / 2 end)
        local result = double:set(10, function(x) return x end)
        assert.equal(5, result)
    end)

    -- ==================== ipairs ====================

    it("`Optic.ipairs` get iterates all array values", function()
        local result = Optic.ipairs():get({10, 20, 30})
        assert.equal(3, #result)
        assert.equal(10, result[1])
        assert.equal(20, result[2])
        assert.equal(30, result[3])
    end)

    it("`Optic.ipairs` set transforms all array values", function()
        local data = {1, 2, 3}
        Optic.ipairs():set(data, function(v) return v * 10 end)
        assert.equal(10, data[1])
        assert.equal(20, data[2])
        assert.equal(30, data[3])
    end)

    -- ==================== ifold ====================

    it("`Optic.ifold` reduces a sequence to a single value", function()
        local sum = Optic.ifold(function(a, b) return a + b end, 0)
        local result = sum:get({1, 2, 3, 4})
        assert.equal(1, #result)
        assert.equal(10, result[1])
    end)

    it("`Optic.ifold` uses first element as seed when no init given", function()
        local product = Optic.ifold(function(a, b) return a * b end)
        local result = product:get({2, 3, 4})
        assert.equal(24, result[1])
    end)

    -- ==================== iaccumulate ====================

    it("`Optic.iaccumulate` yields running totals", function()
        local running = Optic.iaccumulate(function(a, b) return a + b end, 0)
        local result = running:get({1, 2, 3})
        assert.equal(3, #result)
        assert.equal(1, result[1])
        assert.equal(3, result[2])
        assert.equal(6, result[3])
    end)

    -- ==================== chain ====================

    it("`Optic.chain` composes two field optics", function()
        local nested = Optic.chain(Optic.field("a"), Optic.field("b"))
        local result = nested:get({a = {b = "deep"}})
        assert.equal(1, #result)
        assert.equal("deep", result[1])
    end)

    it("`Optic.chain` composes field and ipairs optics", function()
        local items = Optic.chain(Optic.field("list"), Optic.ipairs())
        local result = items:get({list = {10, 20, 30}})
        assert.equal(3, #result)
        assert.equal(10, result[1])
        assert.equal(30, result[3])
    end)

    -- ==================== none ====================

    it("`Optic.none` get always returns empty", function()
        local result = Optic.none():get({a = 1, b = 2})
        assert.equal(0, #result)
    end)

end)
