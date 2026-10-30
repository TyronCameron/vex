local vexdex = require 'core.vexdex'
local lfs = require 'lib.lfs'

describe("vexdex", function()

    it("stores and removes index entries", function()
        vexdex:unsafe_add("__spec-id-1", "/some/path.md")
        assert.equal("/some/path.md", vexdex:get("__spec-id-1"))
        vexdex:unsafe_remove("__spec-id-1")
        assert.is_nil(vexdex:get("__spec-id-1"))
    end)

    it("unsafe_remove on a missing id does not error", function()
        assert.has_no.errors(function()
            vexdex:unsafe_remove("__id-that-does-not-exist")
        end)
    end)

    it("unsafe_link records the linking vexid against each target", function()
        vexdex:unsafe_link("__source", {"__a", "__b"})
        assert.truthy(vexdex.backlinks["__a"]["__source"])
        assert.truthy(vexdex.backlinks["__b"]["__source"])
        vexdex:unsafe_link("__source", {"__a"})
        assert.is_nil(vexdex.backlinks["__b"])
        vexdex:unsafe_remove("__source")
        assert.is_nil(vexdex.backlinks["__a"])
    end)

    it("lists, sorted, the vexids linking to a task", function()
        vexdex:unsafe_link("__b", {"__target", "__other"})
        vexdex:unsafe_link("__a", {"__target"})
        assert.same({"__a", "__b"}, vexdex:linksto("__target"))
        assert.same({}, vexdex:linksto("__nothing"))
        vexdex:unsafe_remove("__a")
        vexdex:unsafe_remove("__b")
    end)

    it("unlinked lists the targets a task linked to that its new links drop", function()
        vexdex:unsafe_link("__source", {"__a", "__b", "__c"})
        assert.same({"__a", "__c"}, vexdex:unlinked("__source", {"__b"}))
        assert.same({}, vexdex:unlinked("__source", {"__a", "__b", "__c", "__d"}))
        assert.same({}, vexdex:unlinked("__nothing", {}))
        vexdex:unsafe_remove("__source")
    end)

    it("unsafe_remove drops a task's backlinks", function()
        vexdex:unsafe_link("__linker", {"__linked"})
        vexdex:unsafe_remove("__linked")
        assert.is_nil(vexdex.backlinks["__linked"])
        vexdex:unsafe_remove("__linker")
    end)

    it("persists the index, backlinks and focus for the next run", function()
        vexdex:unsafe_add("__persisted", {vexid = "__persisted", status = "todo"})
        vexdex:link("__persisted", {"__target"})
        vexdex:setfocus({operations = {{operation = 'focus', args = {'all'}}}})
        local reloaded = vexdex.new(vexdex.path)
        assert.same({vexid = "__persisted", status = "todo"}, reloaded:get("__persisted"))
        assert.truthy(reloaded.backlinks["__target"]["__persisted"])
        assert.same({operations = {{operation = 'focus', args = {'all'}}}}, reloaded:getfocus())
        vexdex:remove("__persisted")
    end)

    it("persists where each task file is, and forgets it when the task is removed", function()
        vexdex:unsafe_locate("__placed", "group/__placed.md"):writeindex()
        assert.equal("group/__placed.md", vexdex.new(vexdex.path).paths["__placed"])
        vexdex:remove("__placed")
        assert.is_nil(vexdex.paths["__placed"])
        assert.is_nil(vexdex.new(vexdex.path).paths["__placed"])
    end)

    it("persists index entries as plain data, without their metatable", function()
        vexdex:add("__object", setmetatable({vexid = "__object"}, {__index = function() return "computed" end}))
        local reloaded = vexdex.new(vexdex.path)
        assert.same({vexid = "__object"}, reloaded:get("__object"))
        assert.is_nil(getmetatable(reloaded:get("__object")))
        vexdex:remove("__object")
    end)

    it("throws a write error when the written file cannot be moved into place", function()
        local cli = require 'lib.cli'
        stub(cli, 'throw', function(self, name) error(name) end)
        local ok, err = pcall(vexdex.atomic, vexdex, vexdex:vexpath("no-such-folder/file.txt"), function(path)
            local f = io.open(path, "w")
            f:write("data")
            f:close()
        end)
        cli.throw:revert()
        for file in lfs.dir(vexdex:vexpath("tmp")) do
            if not file:match("^%.") then os.remove(vexdex:vexpath("tmp/" .. file)) end
        end
        assert.is_false(ok)
        assert.truthy(err:find('write', 1, true))
    end)

    it("leaves nothing behind in .vex/tmp after writing", function()
        vexdex:link("__tmpcheck", {"__target"})
        vexdex:remove("__tmpcheck")
        for file in lfs.dir(vexdex:vexpath("tmp")) do
            assert.truthy(file:match("^%."), "left behind .vex/tmp/" .. file)
        end
    end)

    describe("logs", function()

        local config = require 'core.config'
        local event = require 'lib.event'

        local function lines(file)
            local result = {}
            local path = vexdex:vexpath("vexdex/" .. file)
            if lfs.attributes(path, "mode") ~= "file" then return result end
            for line in io.lines(path) do table.insert(result, line) end
            return result
        end

        before_each(function()
            os.remove(vexdex:vexpath("vexdex/verb-log.txt"))
            os.remove(vexdex:vexpath("vexdex/event-log.txt"))
        end)

        after_each(function()
            config.properties.loglimit = nil
        end)

        it("logs every event, with its args, to event-log.txt", function()
            event:trigger('__spec-event', '__spec-arg')
            local logged = lines("event-log.txt")
            assert.equal(1, #logged)
            assert.truthy(logged[1]:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d\t__spec%-event\t.*__spec%-arg"))
        end)

        it("logs the command line of every verb to verb-log.txt before it runs", function()
            event:trigger('pre-verb-add', {raw = 'add Make coffee --due tomorrow'})
            event:trigger('post-verb-add', {raw = 'add Make coffee --due tomorrow'})
            local logged = lines("verb-log.txt")
            assert.equal(1, #logged)
            assert.truthy(logged[1]:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d\tadd Make coffee %-%-due tomorrow$"))
        end)

        it("keeps only the last loglimit lines of each log", function()
            config.properties.loglimit = 3
            for i = 1, 5 do event:trigger('pre-verb-spec', {raw = 'spec ' .. i}) end
            local logged = lines("verb-log.txt")
            assert.equal(3, #logged)
            assert.truthy(logged[1]:find("spec 3", 1, true))
            assert.truthy(logged[3]:find("spec 5", 1, true))
            assert.equal(3, #lines("event-log.txt"))
        end)

    end)

end)
