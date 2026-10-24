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

    it("`pretty.tabular` has a column for a field only later rows hold, blank where a row lacks it", function()
        local data = {{name = "alice"}, {name = "bob", age = "30"}}
        local result = pretty.tabular(data, pairs)
        assert.truthy(result:find("age"))
        assert.truthy(result:find("30"))
        assert.is_nil(result:find("nil"))
    end)

    it("`pretty.tabular` writes a list as its comma-separated values", function()
        local result = pretty.tabular({{children = {"first-1", "second-1"}}}, pairs)
        assert.truthy(result:find("first-1, second-1", 1, true))
        assert.is_nil(result:find("table:", 1, true))
    end)

    it("`pretty.tabular` cuts a long list short with ...", function()
        local long = {}
        for i = 1, 20 do table.insert(long, "child-task-" .. i) end
        local result = pretty.tabular({{children = long}}, pairs)
        assert.truthy(result:find("child-task-1, ", 1, true))
        assert.truthy(result:find(", ...", 1, true))
        assert.is_nil(result:find("child-task-20", 1, true))
    end)

    local function visiblewidth(line)
        return select(2, line:gsub("\27%[[0-9;]*m", ""):gsub("[^\128-\191]", ""))
    end

    it("`pretty.tabular` keeps a long list within 40 characters", function()
        local long = {}
        for i = 1, 20 do table.insert(long, "child-task-" .. i) end
        local result = pretty.tabular({{children = long}}, pairs)
        local row = result:match("\n│ (child%-task[^\n]-) │")
        assert.truthy(visiblewidth(row:gsub("%s+$", "")) <= 40)
    end)

    it("`pretty.tabular` cuts a long value to 40 characters with ...", function()
        local result = pretty.tabular({{description = string.rep("a", 100)}}, pairs)
        assert.truthy(result:find(string.rep("a", 37) .. "...", 1, true))
        assert.is_nil(result:find(string.rep("a", 38), 1, true))
    end)

    it("`pretty.tabular` cuts values to the given maximum width", function()
        local result = pretty.tabular({{description = "abcdefghijklmnop"}}, pairs, 10)
        assert.truthy(result:find("abcdefg...", 1, true))
        assert.is_nil(result:find("abcdefgh", 1, true))
    end)

    it("`pretty.tabular` cuts a long field name in the header", function()
        local result = pretty.tabular({{[string.rep("f", 50)] = "x"}}, pairs)
        assert.truthy(result:find(string.rep("f", 37) .. "...", 1, true))
        assert.is_nil(result:find(string.rep("f", 38), 1, true))
    end)

    it("`pretty.tabular` aligns every line across long, unicode, styled and multiline values", function()
        local data = {
            {description = string.rep("long ", 30), status = "todo"},
            {description = "café — ok", status = "doing"},
            {description = pretty.string("styled", "bold"), status = "done"},
            {description = "first line\nsecond line", status = "todo"},
        }
        local result = pretty.tabular(data, pairs)
        local lines = {}
        for line in (result .. "\n"):gmatch("(.-)\n") do table.insert(lines, line) end
        assert.equal(#data + 4, #lines)
        for _, line in ipairs(lines) do
            assert.equal(visiblewidth(lines[1]), visiblewidth(line))
        end
    end)

end)
