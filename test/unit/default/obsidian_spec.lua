-- Test file for default/obsidian.lua
local busted = require 'busted'
local obsidian = require 'default.obsidian'

-- obsidian.write expects a coroutine-style iterator, not pairs() directly
local function to_iter(t)
    return coroutine.wrap(function()
        for k, v in pairs(t) do
            coroutine.yield(k, v)
        end
    end)
end

local function writefile(path, content)
    local f = io.open(path, "w")
    f:write(content)
    f:close()
end

describe("obsidian", function()

    it("reads string frontmatter values", function()
        local tmp = os.tmpname()
        writefile(tmp, "---\ntitle: My Task\nstatus: todo\n---\n")

        local task = obsidian.read(tmp)
        assert.equal("My Task", task.title)
        assert.equal("todo",    task.status)

        os.remove(tmp)
    end)

    it("reads boolean frontmatter values", function()
        local tmp = os.tmpname()
        writefile(tmp, "---\nactive: true\nclosed: false\n---\n")

        local task = obsidian.read(tmp)
        assert.is_true(task.active)
        assert.is_false(task.closed)

        os.remove(tmp)
    end)

    it("reads numeric frontmatter values", function()
        local tmp = os.tmpname()
        writefile(tmp, "---\npriority: 3\n---\n")

        local task = obsidian.read(tmp)
        assert.equal(3, task.priority)

        os.remove(tmp)
    end)

    it("reads body content into vexbody", function()
        local tmp = os.tmpname()
        writefile(tmp, "---\ntitle: Test\n---\nHello world")

        local task = obsidian.read(tmp)
        assert.equal("Hello world", task.vexbody)

        os.remove(tmp)
    end)

    it("writes and reads back a file correctly", function()
        local tmp = os.tmpname()
        obsidian.write(tmp, to_iter({title = "Round Trip", priority = 5}), "Body text here")

        local task = obsidian.read(tmp)
        assert.equal("Round Trip", task.title)
        assert.equal(5,            task.priority)
        assert.equal("Body text here", task.vexbody)

        os.remove(tmp)
    end)

    it("round-trips quoted string values", function()
        local tmp = os.tmpname()
        -- to_yaml_value quotes strings containing special characters like ':'
        obsidian.write(tmp, to_iter({note = "has: colon"}), nil)

        local task = obsidian.read(tmp)
        assert.equal("has: colon", task.note)

        os.remove(tmp)
    end)

    -- ==================== List fields (fix-list-field-roundtrip-1) ====================

    it("round-trips a non-empty list field", function()
        local tmp = os.tmpname()
        obsidian.write(tmp, to_iter({children = {"[[a]]", "[[b]]"}}), nil)

        local task = obsidian.read(tmp)
        assert.equal("table", type(task.children))
        assert.same({"[[a]]", "[[b]]"}, task.children)

        os.remove(tmp)
    end)

    it("round-trips an empty list field as an empty table, not an empty string", function()
        local tmp = os.tmpname()
        obsidian.write(tmp, to_iter({children = {}}), nil)

        local task = obsidian.read(tmp)
        assert.equal("table", type(task.children))
        assert.equal(0, #task.children)

        os.remove(tmp)
    end)

    it("round-trips a list field alongside scalar fields", function()
        local tmp = os.tmpname()
        obsidian.write(tmp, to_iter({
            vexid = "ship-v02-1",
            children = {"[[write-release-notes-1]]"},
            status = "todo",
        }), "Body text")

        local task = obsidian.read(tmp)
        assert.equal("ship-v02-1", task.vexid)
        assert.equal("todo", task.status)
        assert.same({"[[write-release-notes-1]]"}, task.children)
        assert.equal("Body text", task.vexbody)

        os.remove(tmp)
    end)

    -- ==================== YAML written by other tools ====================

    local function readtext(content)
        local tmp = os.tmpname()
        writefile(tmp, content)
        local task = obsidian.read(tmp)
        os.remove(tmp)
        return task
    end

    it("reads a flow list, keeping quoted commas and wikilinks", function()
        local task = readtext('---\ncontexts: [office, "home, garden", 3]\nempty: []\nlink: [[a]]\n---\n')
        assert.same({"office", "home, garden", 3}, task.contexts)
        assert.same({}, task.empty)
        assert.equal("[[a]]", task.link)
    end)

    it("reads a list of maps", function()
        local task = readtext('---\nblockedBy:\n  - uid: "[[a]]"\n    reltype: FINISHTOSTART\n  - uid: "[[b]]"\n    gap: P1D\n---\n')
        assert.same({{uid = "[[a]]", reltype = "FINISHTOSTART"}, {uid = "[[b]]", gap = "P1D"}}, task.blockedBy)
    end)

    it("reads a nested map, a list at its key's indent and an empty key", function()
        local task = readtext('---\nTN-meta:\n  at: 2026-10-01T08:00\n  note: "a: b"\ntags:\n- task\n- work\ndue:\nstatus: todo\n---\n')
        assert.same({at = "2026-10-01T08:00", note = "a: b"}, task["TN-meta"])
        assert.same({"task", "work"}, task.tags)
        assert.is_nil(task.due)
        assert.equal("todo", task.status)
    end)

    it("round-trips a list of maps", function()
        local tmp = os.tmpname()
        local entries = {{startTime = "2025-01-20T10:00:00Z", endTime = "2025-01-20T11:30:00Z"}, {startTime = "2025-01-21T10:00:00Z"}}
        obsidian.write(tmp, to_iter({timeEntries = entries}), nil)
        assert.same(entries, obsidian.read(tmp).timeEntries)
        os.remove(tmp)
    end)

    describe("strings that are not plain text", function()

        local awkward = {
            'say "hi"', '"quoted"', '"', 'a\\b', 'a\\"b', 'ends with backslash\\', 'c:\\dir\\file',
            'line1\nline2', 'cr\r\nlf', 'tab\there', '', ' ',
            '123', '1e5', '0x10', 'true', 'false', 'null', '~',
            "it's", "'single'", '- dash', '# hash', 'key: value', '[[link]]', '{curly}', 'ünï 🎉',
        }

        local function roundtrip(value)
            local tmp = os.tmpname()
            obsidian.write(tmp, to_iter({field = value}), nil)
            local back = obsidian.read(tmp).field
            os.remove(tmp)
            return back
        end

        for _, value in ipairs(awkward) do
            it(string.format("round-trips %q as a value", value), function()
                assert.equal(value, roundtrip(value))
            end)

            it(string.format("round-trips %q as a list item", value), function()
                assert.same({value, "other"}, roundtrip({value, "other"}))
            end)
        end

        it("reads a quote escaped by an older writer", function()
            local tmp = os.tmpname()
            writefile(tmp, '---\ndescription: "say \\"hi\\" there"\n---\n')
            assert.equal('say "hi" there', obsidian.read(tmp).description)
            os.remove(tmp)
        end)

        it("keeps a backslash that does not start an escape", function()
            local tmp = os.tmpname()
            writefile(tmp, '---\ndescription: "c:\\dir file"\n---\n')
            assert.equal('c:\\dir file', obsidian.read(tmp).description)
            os.remove(tmp)
        end)

        it("reads a doubled single quote as one", function()
            local tmp = os.tmpname()
            writefile(tmp, "---\ndescription: 'it''s here'\n---\n")
            assert.equal("it's here", obsidian.read(tmp).description)
            os.remove(tmp)
        end)

    end)

end)
