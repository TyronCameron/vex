-- Test file for default/canonicalvexid.lua
local busted = require 'busted'
local cv = require 'default.canonicalvexid'

describe("canonicalvexid", function()

    it("generates an id from a description", function()
        local id = cv.generate("My important task", {})
        assert.is_string(id)
        assert.truthy(id:match("-1$"))
    end)

    it("lowercases all words", function()
        local id = cv.generate("Hello World", {})
        assert.equal("hello-world-1", id)
    end)

    it("strips non-alphanumeric characters from words", function()
        local id = cv.generate("hello, world!", {})
        assert.equal("hello-world-1", id)
    end)

    it("filters common filler words", function()
        -- 'the', 'a', 'is', 'for' are filler words
        local id = cv.generate("the quick fox", {})
        assert.falsy(id:match("^the%-"))
        assert.truthy(id:match("^quick%-"))
    end)

    it("uses at most 4 meaningful words", function()
        local id = cv.generate("one two three four five six seven", {})
        -- id should be "one-two-three-four-1" (4 words + counter)
        local parts = {}
        for part in id:gmatch("[^-]+") do table.insert(parts, part) end
        assert.equal(5, #parts)  -- 4 words + "1"
    end)

    it("starts the counter at 1 for a fresh lookup", function()
        local id = cv.generate("hello world", {})
        assert.equal("hello-world-1", id)
    end)

    it("increments the counter when the id already exists", function()
        local lookup = { ["hello-world-1"] = true }
        local id = cv.generate("hello world", lookup)
        assert.equal("hello-world-2", id)
    end)

    it("keeps incrementing past multiple existing ids", function()
        local lookup = {
            ["hello-world-1"] = true,
            ["hello-world-2"] = true,
            ["hello-world-3"] = true,
        }
        local id = cv.generate("hello world", lookup)
        assert.equal("hello-world-4", id)
    end)

end)
