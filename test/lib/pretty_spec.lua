-- Test file for lib/pretty.lua
local busted = require 'busted'
local pretty = require 'lib.pretty'

describe("pretty", function()

    -- ==================== pretty.table ====================

    it("`pretty.table` formats an empty table as {}", function()
        assert.equal("{}", pretty.table({}))
    end)

    it("`pretty.table` formats a number", function()
        assert.equal("42", pretty.table(42))
    end)

    it("`pretty.table` formats a boolean", function()
        assert.equal("true",  pretty.table(true))
        assert.equal("false", pretty.table(false))
    end)

    it("`pretty.table` formats a string with quotes", function()
        assert.equal('"hello"', pretty.table("hello"))
    end)

    it("`pretty.table` formats a table with key-value pairs", function()
        local result = pretty.table({name = "alice"})
        assert.truthy(result:find("name"))
        assert.truthy(result:find("alice"))
    end)

    it("`pretty.table` handles nested tables", function()
        local result = pretty.table({outer = {inner = 1}})
        assert.truthy(result:find("outer"))
        assert.truthy(result:find("inner"))
    end)

    it("`pretty.table` detects circular references", function()
        local t = {}
        t.self = t
        local result = pretty.table(t)
        assert.truthy(result:find("<circular>"))
    end)

    -- ==================== pretty.any ====================

    it("`pretty.any` converts a number to string", function()
        local result = pretty.any(42)
        assert.truthy(result:find("42"))
    end)

    it("`pretty.any` converts a string directly", function()
        local result = pretty.any("hello")
        assert.truthy(result:find("hello"))
    end)

    it("`pretty.any` handles multiple arguments", function()
        local result = pretty.any("a", "b")
        assert.truthy(result:find("a"))
        assert.truthy(result:find("b"))
    end)

    -- ==================== pretty.string (PrettyString) ====================

    it("`pretty.string` returns bare text with no styles", function()
        assert.equal("hello", pretty.string("hello"))
    end)

    it("`pretty.string` wraps text in ANSI codes when a style is applied", function()
        local result = pretty.string("hello", "bold")
        assert.truthy(result:find("hello"))
        assert.truthy(result:find("\27%["))
    end)

    it("`pretty.string` supports named colors", function()
        local result = pretty.string("hello", "red")
        assert.truthy(result:find("hello"))
        assert.truthy(result:find("\27%["))
    end)

    -- ==================== pretty.markdown ====================

    it("`pretty.markdown` styles h1 headers with bold", function()
        local result = pretty.markdown("# Title\n")
        assert.truthy(result:find("Title"))
        assert.truthy(result:find("\27%[1m"))
    end)

    it("`pretty.markdown` styles **bold** text", function()
        local result = pretty.markdown("**important**")
        assert.truthy(result:find("important"))
        assert.truthy(result:find("\27%[1m"))
    end)

    it("`pretty.markdown` styles *italic* text", function()
        local result = pretty.markdown("*note*")
        assert.truthy(result:find("note"))
        assert.truthy(result:find("\27%[3m"))
    end)

    -- ==================== pretty.tabular ====================

    it("`pretty.tabular` returns empty string for empty input", function()
        assert.equal("", pretty.tabular({}))
    end)

    it("`pretty.tabular` contains field names as headers", function()
        local data = {{name = "alice", age = "30"}}
        local result = pretty.tabular(data, pairs)
        assert.truthy(result:find("name"))
        assert.truthy(result:find("age"))
    end)

    it("`pretty.tabular` contains data values", function()
        local data = {{name = "alice", age = "30"}}
        local result = pretty.tabular(data, pairs)
        assert.truthy(result:find("alice"))
        assert.truthy(result:find("30"))
    end)

end)
