local vexdex = require 'core.vexdex'
local lfs = require 'lib.lfs'
local lfsext = require 'lib.lfsext'
local func = require 'lib.func'

describe("vexdex", function()

    it("stores and removes index entries", function()
        vexdex:unsafe_add("__spec-id-1", {vexid = "__spec-id-1"})
        assert.same({vexid = "__spec-id-1"}, vexdex:get("__spec-id-1"))
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

    it("fingerprints a task with its body, leaving out the fields config excludes", function()
        local task = {vexid = "__printed", cost = 1, modified = 10, vexbody = "notes"}
        local before = vexdex:fingerprint(task)
        assert.equal(before, vexdex:fingerprint({vexid = "__printed", cost = 1, modified = 20, vexbody = "notes"}))
        assert.not_equal(before, vexdex:fingerprint({vexid = "__printed", cost = 2, modified = 10, vexbody = "notes"}))
        assert.not_equal(before, vexdex:fingerprint({vexid = "__printed", cost = 1, modified = 10, vexbody = "other notes"}))
    end)

    it("tells a task that changed since it was indexed from one that did not, and from one never indexed", function()
        assert.is_false(vexdex:changed("__compared", {vexid = "__compared", cost = 1}))
        vexdex:unsafe_add("__compared", {vexid = "__compared", cost = 1})
        assert.is_false(vexdex:changed("__compared", {vexid = "__compared", cost = 1}))
        assert.is_true(vexdex:changed("__compared", {vexid = "__compared", cost = 2}))
        vexdex:unsafe_remove("__compared")
    end)

    it("persists fingerprints and mtimes, and forgets them when the task is removed", function()
        local path = vexdex:taskroot() .. "/__stamped.md"
        local f = io.open(path, "w")
        f:write("stamped")
        f:close()
        vexdex:unsafe_add("__stamped", {vexid = "__stamped"}):unsafe_stamp("__stamped", path):writeindex()
        local reloaded = vexdex.new(vexdex.path)
        assert.equal(vexdex:fingerprint({vexid = "__stamped"}), reloaded.fingerprints["__stamped"])
        assert.equal(lfsext.mtime(path), reloaded.mtimes["__stamped"])
        vexdex:remove("__stamped")
        assert.is_nil(vexdex.new(vexdex.path).mtimes["__stamped"])
        os.remove(path)
    end)

    it("lists the indexed tasks whose files changed or went missing, and the files it does not know", function()
        local root = vexdex:taskroot()
        for _, name in ipairs({"__kept", "__touched", "__gone", "__unknown"}) do
            local f = io.open(root .. "/" .. name .. ".md", "w")
            f:write(name)
            f:close()
        end
        for _, vexid in ipairs({"__kept", "__touched", "__gone"}) do
            vexdex:unsafe_locate(vexid, vexid .. ".md"):unsafe_stamp(vexid, root .. "/" .. vexid .. ".md")
        end
        os.execute("touch -d '2001-01-01 00:00:00' '" .. root .. "/__touched.md'")
        os.remove(root .. "/__gone.md")
        local changed, unknown = vexdex:updated()
        assert.same({"__gone", "__touched"}, func.ifilter(changed, function(vexid) return vexid:match("^__") end))
        assert.truthy(func.any(unknown, function(path) return path == root .. "/__unknown.md" end))
        assert.is_false(func.any(unknown, function(path) return path:match("__kept") ~= nil end))
        for _, name in ipairs({"__kept", "__touched", "__unknown"}) do os.remove(root .. "/" .. name .. ".md") end
        for _, vexid in ipairs({"__kept", "__touched", "__gone"}) do vexdex:unsafe_remove(vexid) end
    end)

    it("persists index entries without their body, in both the index and its readable copy", function()
        vexdex:add("__bodied", {vexid = "__bodied", status = "todo", vexbody = "private notes"})
        assert.equal("private notes", vexdex:get("__bodied").vexbody)
        assert.same({vexid = "__bodied", status = "todo"}, vexdex.new(vexdex.path):get("__bodied"))
        local mirror = io.open(vexdex:vexpath("vexdex/index.lua")):read("*a")
        assert.is_nil(mirror:find("private notes", 1, true))
        assert.truthy(mirror:find("__bodied", 1, true))
        vexdex:remove("__bodied")
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

    describe("saving", function()
        local event = require 'lib.event'

        before_each(function() vexdex:writeindex() end)

        it("is dirty once the index changes and clean once it is written", function()
            assert.is_false(vexdex.dirty)
            vexdex:unsafe_add("__dirty", {vexid = "__dirty"})
            assert.is_true(vexdex.dirty)
            vexdex:writeindex()
            assert.is_false(vexdex.dirty)
            vexdex:remove("__dirty")
        end)

        it("stays clean when a task is located where it already is", function()
            vexdex:unsafe_locate("__where", "a/__where.md"):writeindex()
            vexdex:unsafe_locate("__where", "a/__where.md")
            assert.is_false(vexdex.dirty)
            vexdex:unsafe_locate("__where", "b/__where.md")
            assert.is_true(vexdex.dirty)
            vexdex:remove("__where")
        end)

        it("does not reach the disk until a verb finishes", function()
            vexdex:unsafe_add("__staged", {vexid = "__staged"})
            assert.is_nil(vexdex.new(vexdex.path):get("__staged"))
            event:trigger('post-verb-get', {}, nil)
            assert.same({vexid = "__staged"}, vexdex.new(vexdex.path):get("__staged"))
            assert.is_false(vexdex.dirty)
            vexdex:remove("__staged")
        end)
    end)

end)
