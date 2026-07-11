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

end)
