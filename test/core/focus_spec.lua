local busted = require 'busted'
local Focus = require 'core.focus'

describe("Focus", function()

    local t1 = {vexid = "t1", status = "todo"}
    local t2 = {vexid = "t2", status = "done"}
    local t3 = {vexid = "t3", status = "todo"}
    local all = {t1, t2, t3}

    it("Focus.new creates a Focus instance", function()
        local f = Focus.new("test", function(t) return t end)
        assert.truthy(f)
        assert.is_function(f.get)
    end)

    it("Focus:get returns tasks via the provided get function", function()
        local f = Focus.new("test", function(t) return t end)
        local result = f:get(all)
        assert.equal(3, #result)
    end)

    it("Focus:get with empty input returns empty table", function()
        local f = Focus.new("test", function(t) return t end)
        local result = f:get({})
        assert.equal(0, #result)
    end)

    it("union returns tasks from both focuses", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[3]} end)
        local result = f1:union(f2):get(all)
        assert.equal(3, #result)
    end)

    it("union deduplicates tasks shared between focuses", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[1]} end)
        local result = f1:union(f2):get(all)
        assert.equal(2, #result)
    end)

    it("intersect returns only tasks present in both focuses", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[2], t[3]} end)
        local result = f1:intersect(f2):get(all)
        assert.equal(1, #result)
        assert.equal(t2, result[1])
    end)

    it("intersect with empty focus returns empty", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f_empty = Focus.new("empty", function(t) return {} end)
        local result = f1:intersect(f_empty):get(all)
        assert.equal(0, #result)
    end)

    it("notin returns tasks in first but not in second", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[2]} end)
        local result = f1:notin(f2):get(all)
        assert.equal(1, #result)
    end)

    it("filter returns only tasks matching the given field value", function()
        local tasks = {
            {vexid = "a", status = "todo"},
            {vexid = "b", status = "done"},
            {vexid = "c", status = "todo"},
        }
        local f = Focus.new("all", function(t) return t end)
        local result = f:filter("status", "todo"):get(tasks)
        assert.equal(2, #result)
    end)

    it("union returns a chainable Focus", function()
        local f1 = Focus.new("f1", function(t) return {t[1]} end)
        local f2 = Focus.new("f2", function(t) return {t[2]} end)
        local combined = f1:union(f2)
        assert.truthy(combined)
        assert.is_function(combined.get)
    end)

    it("complement returns tasks NOT in the focus", function()
        local f1 = Focus.new("f1", function(t) return {t[1]} end)
        local orig = Focus.getalltasks
        Focus.getalltasks = function() return all end
        local result = f1:complement():get(all)
        Focus.getalltasks = orig
        assert.equal(2, #result)
    end)

end)
