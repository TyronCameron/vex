-- Test file for default/obsidian.lua
local busted = require 'busted'
local obsidian = require 'default.obsidian'

-- obsidian.render expects a coroutine-style iterator, not pairs() directly
local function to_iter(t)
    return coroutine.wrap(function()
        for k, v in pairs(t) do
            coroutine.yield(k, v)
        end
    end)
end

local function roundtrip(fields, body)
    return obsidian.parse(obsidian.render(to_iter(fields), body))
end

describe("obsidian", function()

    it("parses string frontmatter values", function()
        local task = obsidian.parse("---\ntitle: My Task\nstatus: todo\n---\n")
        assert.equal("My Task", task.title)
        assert.equal("todo",    task.status)
    end)

    it("parses boolean frontmatter values", function()
        local task = obsidian.parse("---\nactive: true\nclosed: false\n---\n")
        assert.is_true(task.active)
        assert.is_false(task.closed)
    end)

    it("parses numeric frontmatter values", function()
        assert.equal(3, obsidian.parse("---\npriority: 3\n---\n").priority)
    end)

    it("parses body content into vexbody", function()
        assert.equal("Hello world", obsidian.parse("---\ntitle: Test\n---\nHello world").vexbody)
    end)

    it("parses text without frontmatter as no task", function()
        assert.is_nil(obsidian.parse("# Just a note\n"))
    end)

    it("refuses frontmatter that is never closed", function()
        assert.has_error(function() obsidian.parse("---\nvexid: broken-1\n") end)
    end)

    it("renders frontmatter between fences, then the body", function()
        assert.equal("---\nstatus: todo\n---\nBody text", obsidian.render(to_iter({status = "todo"}), "Body text"))
        assert.equal("---\nstatus: todo\n---\n", obsidian.render(to_iter({status = "todo"}), nil))
    end)

    it("renders and parses back a task", function()
        local task = roundtrip({title = "Round Trip", priority = 5}, "Body text here")
        assert.equal("Round Trip", task.title)
        assert.equal(5,            task.priority)
        assert.equal("Body text here", task.vexbody)
    end)

    it("round-trips quoted string values", function()
        assert.equal("has: colon", roundtrip({note = "has: colon"}).note)
    end)

    -- ==================== List fields (fix-list-field-roundtrip-1) ====================

    it("round-trips a non-empty list field", function()
        local task = roundtrip({children = {"[[a]]", "[[b]]"}})
        assert.equal("table", type(task.children))
        assert.same({"[[a]]", "[[b]]"}, task.children)
    end)

    it("round-trips an empty list field as an empty table, not an empty string", function()
        local task = roundtrip({children = {}})
        assert.equal("table", type(task.children))
        assert.equal(0, #task.children)
    end)

    it("round-trips a list field alongside scalar fields", function()
        local task = roundtrip({
            vexid = "ship-v02-1",
            children = {"[[write-release-notes-1]]"},
            status = "todo",
        }, "Body text")
        assert.equal("ship-v02-1", task.vexid)
        assert.equal("todo", task.status)
        assert.same({"[[write-release-notes-1]]"}, task.children)
        assert.equal("Body text", task.vexbody)
    end)

    -- ==================== YAML written by other tools ====================

    it("parses a flow list, keeping quoted commas and wikilinks", function()
        local task = obsidian.parse('---\ncontexts: [office, "home, garden", 3]\nempty: []\nlink: [[a]]\n---\n')
        assert.same({"office", "home, garden", 3}, task.contexts)
        assert.same({}, task.empty)
        assert.equal("[[a]]", task.link)
    end)

    it("parses a list of maps", function()
        local task = obsidian.parse('---\nblockedBy:\n  - uid: "[[a]]"\n    reltype: FINISHTOSTART\n  - uid: "[[b]]"\n    gap: P1D\n---\n')
        assert.same({{uid = "[[a]]", reltype = "FINISHTOSTART"}, {uid = "[[b]]", gap = "P1D"}}, task.blockedBy)
    end)

    it("parses a nested map, a list at its key's indent and an empty key", function()
        local task = obsidian.parse('---\nTN-meta:\n  at: 2026-10-01T08:00\n  note: "a: b"\ntags:\n- task\n- work\ndue:\nstatus: todo\n---\n')
        assert.same({at = "2026-10-01T08:00", note = "a: b"}, task["TN-meta"])
        assert.same({"task", "work"}, task.tags)
        assert.is_nil(task.due)
        assert.equal("todo", task.status)
    end)

    it("round-trips a list of maps", function()
        local entries = {{startTime = "2025-01-20T10:00:00Z", endTime = "2025-01-20T11:30:00Z"}, {startTime = "2025-01-21T10:00:00Z"}}
        assert.same(entries, roundtrip({timeEntries = entries}).timeEntries)
    end)

    describe("strings that are not plain text", function()

        local awkward = {
            'say "hi"', '"quoted"', '"', 'a\\b', 'a\\"b', 'ends with backslash\\', 'c:\\dir\\file',
            'line1\nline2', 'cr\r\nlf', 'tab\there', '', ' ',
            '123', '1e5', '0x10', 'true', 'false', 'null', '~',
            "it's", "'single'", '- dash', '# hash', 'key: value', '[[link]]', '{curly}', 'ünï 🎉',
        }

        for _, value in ipairs(awkward) do
            it(string.format("round-trips %q as a value", value), function()
                assert.equal(value, roundtrip({field = value}).field)
            end)

            it(string.format("round-trips %q as a list item", value), function()
                assert.same({value, "other"}, roundtrip({field = {value, "other"}}).field)
            end)
        end

        it("parses a quote escaped by an older writer", function()
            assert.equal('say "hi" there', obsidian.parse('---\ndescription: "say \\"hi\\" there"\n---\n').description)
        end)

        it("keeps a backslash that does not start an escape", function()
            assert.equal('c:\\dir file', obsidian.parse('---\ndescription: "c:\\dir file"\n---\n').description)
        end)

        it("parses a doubled single quote as one", function()
            assert.equal("it's here", obsidian.parse("---\ndescription: 'it''s here'\n---\n").description)
        end)

    end)

    describe("format", function()

        local function plain(s)
            return (s:gsub("\27%[[%d;]*m", ""))
        end

        it("keeps a file's text exactly as written", function()
            local text = '---\nstatus: todo\ndue: tomorrow 8am\nchildren:\n  - "[[a-1]]"\n---\nSome notes\n'
            assert.equal(text, plain(obsidian.format(text)))
        end)

        it("marks each frontmatter key and the fences, and leaves the body plain", function()
            local shown = obsidian.format('---\nstatus: todo\n---\nstatus: not a key\n')
            assert.truthy(shown:find("\27%[[%d;]*m%-%-%-"))
            assert.truthy(shown:find("\27%[[%d;]*mstatus:"))
            assert.truthy(shown:find("\nstatus: not a key\n", 1, true))
        end)

    end)

end)
