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

    it("`pretty.tabular` cuts a linked value but keeps the link to the whole value", function()
        local path = "/some/long/folder/" .. string.rep("a", 60) .. ".md"
        local result = pretty.tabular({{path = pretty.filelink(path, path)}}, pairs)
        assert.truthy(result:find("...", 1, true))
        assert.truthy(result:find("\27]8;;file://" .. path .. "\27\\", 1, true))
    end)

    it("`pretty.tabular` pads a linked value by what shows", function()
        local lines = pretty.tabular({{a = pretty.filelink("abc", "/x")}, {a = "abcdef"}}, pairs)
        assert.truthy(lines:find("abc\27]8;;\27\\    ", 1, true))
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

    local function plainlines(result)
        local lines = {}
        for line in (result:gsub("\27%[[0-9;]*m", "") .. "\n"):gmatch("(.-)\n") do table.insert(lines, line) end
        return lines
    end

    it("`pretty.tabular` shows a subheader as its field and value, without making it a column", function()
        local result = pretty.tabular({pretty.subheader("owner", "tyron", 0), {vexid = "fix-thing-1"}}, pairs)
        local lines = plainlines(result)
        assert.truthy(lines[4]:find("│ owner: tyron", 1, true))
        assert.truthy(lines[5]:find("│ │ fix-thing-1", 1, true))
        assert.is_nil(result:find("label", 1, true))
    end)

    it("`pretty.tabular` indents nested subheaders and their rows with a guide per level", function()
        local data = {
            pretty.subheader("owner", "tyron", 0),
            pretty.subheader("status", "doing", 1),
            {vexid = "fix-thing-1"},
            pretty.subheader("owner", "sam", 0),
            pretty.subheader("status", "todo", 1),
            {vexid = "ship-it-1"},
        }
        local lines = plainlines(pretty.tabular(data, pairs))
        assert.truthy(lines[4]:find("^│ owner: tyron "))
        assert.truthy(lines[5]:find("^│ │ status: doing "))
        assert.truthy(lines[6]:find("^│ │ │ fix%-thing%-1 "))
        assert.truthy(lines[7]:find("^│ owner: sam "))
        assert.truthy(lines[9]:find("^│ │ │ ship%-it%-1 "))
    end)

    it("`pretty.tabular` gives a subheader's list the table's whole width", function()
        local lineage = {"create-plugins-1", "complete-vexations-plugin-1"}
        local result = pretty.tabular({pretty.subheader("lineage", lineage, 0), {vexid = "x", description = string.rep("d", 60), notes = string.rep("n", 60)}}, pairs)
        assert.truthy(result:find("lineage: create-plugins-1, complete-vexations-plugin-1", 1, true))
    end)

    it("`pretty.tabular` draws the guides dim", function()
        local result = pretty.tabular({pretty.subheader("owner", "tyron", 0), {vexid = "x"}}, pairs)
        assert.truthy(result:find(pretty.string("│", "dim"), 1, true))
    end)

    it("`pretty.tabular` shows a list or missing value in a subheader like a cell", function()
        local lines = plainlines(pretty.tabular({pretty.subheader("lineage", {"top-1", "middle-1"}, 0), {vexid = "x"}, pretty.subheader("owner", nil, 0), {vexid = "y"}}, pairs))
        assert.truthy(lines[4]:find("lineage: top-1, middle-1", 1, true))
        assert.truthy(lines[6]:find("owner: ", 1, true))
        assert.is_nil(lines[6]:find("nil", 1, true))
    end)

    it("`pretty.tabular` aligns every line with nested subheaders and long values", function()
        local data = {
            pretty.subheader("description", string.rep("long ", 30), 0),
            pretty.subheader("status", "doing", 1),
            {vexid = "x", description = string.rep("long ", 30)},
            pretty.subheader("description", "short", 0),
            pretty.subheader("status", "todo", 1),
            {vexid = "a-much-longer-vexid-than-x-1", description = "café"},
        }
        local result = pretty.tabular(data, pairs)
        local lines = {}
        for line in (result .. "\n"):gmatch("(.-)\n") do table.insert(lines, line) end
        assert.equal(#data + 4, #lines)
        for _, line in ipairs(lines) do
            assert.equal(visiblewidth(lines[1]), visiblewidth(line))
        end
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
