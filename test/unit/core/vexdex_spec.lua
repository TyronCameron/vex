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
        vexdex:unsafe_link("__source", {"__a"}, {"__a", "__b"})
        assert.is_nil(vexdex.backlinks["__b"])
        vexdex:unsafe_remove("__source", {"__a"})
        assert.is_nil(vexdex.backlinks["__a"])
    end)

    it("lists, sorted, the vexids linking to a task", function()
        vexdex:unsafe_link("__b", {"__target", "__other"})
        vexdex:unsafe_link("__a", {"__target"})
        assert.same({"__a", "__b"}, vexdex:linksto("__target"))
        assert.same({}, vexdex:linksto("__nothing"))
        vexdex:unsafe_remove("__a", {"__target"})
        vexdex:unsafe_remove("__b", {"__target", "__other"})
    end)

    it("unsafe_remove drops a task's backlinks", function()
        vexdex:unsafe_link("__linker", {"__linked"})
        vexdex:unsafe_remove("__linked")
        assert.is_nil(vexdex.backlinks["__linked"])
        vexdex:unsafe_remove("__linker", {"__linked"})
    end)

    it("persists the index, backlinks and focus for the next run", function()
        vexdex:unsafe_add("__persisted", {vexid = "__persisted", status = "todo"})
        vexdex:link("__persisted", {"__target"})
        vexdex:setfocus({operations = {{operation = 'focus', args = {'all'}}}})
        local reloaded = vexdex.new(vexdex.path)
        assert.same({vexid = "__persisted", status = "todo"}, reloaded:get("__persisted"))
        assert.truthy(reloaded.backlinks["__target"]["__persisted"])
        assert.same({operations = {{operation = 'focus', args = {'all'}}}}, reloaded:getfocus())
        vexdex:remove("__persisted", {"__target"})
    end)

    it("starts an empty index in memory, without writing one, where none exists", function()
        local dir = os.tmpname()
        os.remove(dir)
        lfs.mkdir(dir)
        lfs.mkdir(dir .. "/.vex")
        local fresh = vexdex.new(dir)
        assert.same({}, fresh.index)
        assert.is_nil(lfs.attributes(dir .. "/.vex/vexdex/index.bin"))
        os.execute("rm -rf '" .. dir .. "'")
    end)

    it("persists where each task file is, and forgets it when the task is removed", function()
        vexdex:unsafe_locate("__placed", "group/__placed.md"):writeindex()
        assert.equal("group/__placed.md", vexdex.new(vexdex.path).paths["__placed"])
        vexdex:remove("__placed")
        assert.is_nil(vexdex.paths["__placed"])
        assert.is_nil(vexdex.new(vexdex.path).paths["__placed"])
    end)

    it("fingerprints a task with its body, leaving out the given fields", function()
        local task = {vexid = "__printed", cost = 1, modified = 10, vexbody = "notes"}
        local before = vexdex:fingerprint(task, {"modified"})
        assert.equal(before, vexdex:fingerprint({vexid = "__printed", cost = 1, modified = 20, vexbody = "notes"}, {"modified"}))
        assert.not_equal(vexdex:fingerprint(task), vexdex:fingerprint({vexid = "__printed", cost = 1, modified = 20, vexbody = "notes"}))
        assert.not_equal(before, vexdex:fingerprint({vexid = "__printed", cost = 2, modified = 10, vexbody = "notes"}, {"modified"}))
        assert.not_equal(before, vexdex:fingerprint({vexid = "__printed", cost = 1, modified = 10, vexbody = "other notes"}, {"modified"}))
    end)

    it("tells whether a task changed since it was indexed, and whether outside the fields config excludes", function()
        assert.same({true, true}, {vexdex:changed("__compared", {vexid = "__compared", cost = 1, modified = 1})})
        vexdex:unsafe_add("__compared", {vexid = "__compared", cost = 1, modified = 1})
        assert.same({false, false}, {vexdex:changed("__compared", {vexid = "__compared", cost = 1, modified = 1})})
        assert.same({true, false}, {vexdex:changed("__compared", {vexid = "__compared", cost = 1, modified = 2})})
        assert.same({true, true}, {vexdex:changed("__compared", {vexid = "__compared", cost = 2, modified = 1})})
        vexdex:unsafe_remove("__compared")
    end)

    it("persists fingerprints and mtimes, and forgets them when the task is removed", function()
        local path = vexdex:taskroot() .. "/__stamped.md"
        local f = io.open(path, "w")
        f:write("stamped")
        f:close()
        vexdex:unsafe_add("__stamped", {vexid = "__stamped"}):unsafe_stamp("__stamped", path):writeindex()
        local reloaded = vexdex.new(vexdex.path)
        assert.same(vexdex.fingerprints["__stamped"], reloaded.fingerprints["__stamped"])
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

    it("keeps index entries without their body, in memory and on disk", function()
        vexdex:add("__bodied", {vexid = "__bodied", status = "todo", vexbody = "private notes"})
        assert.same({vexid = "__bodied", status = "todo"}, vexdex:get("__bodied"))
        assert.same({vexid = "__bodied", status = "todo"}, vexdex.new(vexdex.path):get("__bodied"))
        local stored = io.open(vexdex:vexpath("vexdex/index.bin"), "rb"):read("*a")
        assert.is_nil(stored:find("private notes", 1, true))
        assert.truthy(stored:find("__bodied", 1, true))
        vexdex:remove("__bodied")
    end)

    it("still counts the body towards a task's fingerprint", function()
        vexdex:unsafe_add("__printed-body", {vexid = "__printed-body", vexbody = "notes"})
        assert.is_false(vexdex:changed("__printed-body", {vexid = "__printed-body", vexbody = "notes"}))
        assert.is_true(vexdex:changed("__printed-body", {vexid = "__printed-body", vexbody = "other notes"}))
        vexdex:unsafe_remove("__printed-body")
    end)

    it("keeps an index entry's metatable in memory", function()
        local Task = {__index = function() return "computed" end}
        vexdex:unsafe_add("__wrapped", setmetatable({vexid = "__wrapped", vexbody = "notes"}, Task))
        assert.equal(Task, getmetatable(vexdex:get("__wrapped")))
        vexdex:unsafe_remove("__wrapped")
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
        vexdex:remove("__tmpcheck", {"__target"})
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
            vexdex:closelog("verb-log.txt"):closelog("event-log.txt")
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

        it("keeps event-log.txt within loglimit once a verb has finished", function()
            config.properties.loglimit = 3
            event:trigger('pre-verb-spec', {raw = 'spec'})
            for i = 1, 10 do event:trigger('__spec-event', 'arg ' .. i) end
            event:trigger('post-verb-spec', {raw = 'spec'}, nil)
            local logged = lines("event-log.txt")
            assert.equal(3, #logged)
            assert.truthy(logged[2]:find("arg 10", 1, true))
            assert.truthy(logged[3]:find("post-verb-spec", 1, true))
        end)

        it("logs a table arg by its raw text, or as a table, rather than printing it whole", function()
            event:trigger('__spec-event', {raw = 'add Make coffee'}, {nested = {deep = 'value'}})
            local logged = lines("event-log.txt")[1]
            assert.truthy(logged:find("add Make coffee", 1, true))
            assert.is_nil(logged:find("deep", 1, true))
        end)

        it("cuts a long arg short in the event log", function()
            event:trigger('__spec-event', string.rep("a", 1000), {raw = string.rep("b", 1000)})
            local logged = lines("event-log.txt")[1]
            assert.is_true(#logged < 600)
            assert.truthy(logged:find("a...", 1, true))
        end)

        it("keeps 100 lines of each log by default", function()
            for i = 1, 120 do event:trigger('pre-verb-spec', {raw = 'spec ' .. i}) end
            assert.equal(100, #lines("verb-log.txt"))
            assert.equal(100, #lines("event-log.txt"))
        end)

    end)

    describe("saving", function()
        local event = require 'lib.event'

        it("reaches the disk only when writeindex commits it, never when a verb finishes", function()
            vexdex:unsafe_add("__staged", {vexid = "__staged"})
            event:trigger('post-verb-get', {}, nil)
            assert.is_nil(vexdex.new(vexdex.path):get("__staged"))
            vexdex:writeindex()
            assert.same({vexid = "__staged"}, vexdex.new(vexdex.path):get("__staged"))
            vexdex:remove("__staged")
        end)
    end)

end)
