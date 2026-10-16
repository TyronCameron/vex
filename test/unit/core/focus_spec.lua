local Focus = require 'core.focus'

describe("Focus", function()

    local t1 = {vexid = "t1", status = "todo"}
    local t2 = {vexid = "t2", status = "done"}
    local t3 = {vexid = "t3", status = "todo"}
    local all = {t1, t2, t3}

    it("Focus:get returns tasks via the provided get function", function()
        local f = Focus.new("test", function(t) return t end)
        local result = f:get(all)
        assert.equal(3, #result)
    end)

    it("Focus:get with empty input returns empty table", function()
        local f = Focus.new("test", function(t) return t end)
        local result = f:get({})
        assert.equal(0, #result)
    end)

    it("union returns tasks from both focuses", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[3]} end)
        local result = f1:union(f2):get(all)
        assert.equal(3, #result)
    end)

    it("union deduplicates tasks shared between focuses", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[1]} end)
        local result = f1:union(f2):get(all)
        assert.equal(2, #result)
    end)

    it("intersect returns only tasks present in both focuses", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[2], t[3]} end)
        local result = f1:intersect(f2):get(all)
        assert.equal(1, #result)
        assert.equal(t2, result[1])
    end)

    it("intersect with empty focus returns empty", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f_empty = Focus.new("empty", function(t) return {} end)
        local result = f1:intersect(f_empty):get(all)
        assert.equal(0, #result)
    end)

    it("notin returns tasks in first but not in second", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[2]} end)
        local result = f1:notin(f2):get(all)
        assert.equal(1, #result)
    end)

    it("filter returns only tasks matching the given field value", function()
        local tasks = {
            {vexid = "a", status = "todo"},
            {vexid = "b", status = "done"},
            {vexid = "c", status = "todo"},
        }
        local f = Focus.new("all", function(t) return t end)
        local result = f:filter("status", "todo"):get(tasks)
        assert.equal(2, #result)
    end)

    it("complement returns tasks NOT in the focus", function()
        local f1 = Focus.new("f1", function(t) return {t[1]} end)
        local orig = Focus.getalltasks
        Focus.getalltasks = function() return all end
        local result = f1:complement():get(all)
        Focus.getalltasks = orig
        assert.equal(2, #result)
    end)

    it("xor returns tasks in exactly one of the focuses", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[2], t[3]} end)
        local result = f1:xor(f2):get(all)
        assert.equal(2, #result)
        assert.is_nil(({[result[1]] = true, [result[2]] = true})[t2])
    end)

    it("onlyin returns tasks in the second focus but not the first", function()
        local f1 = Focus.new("f1", function(t) return {t[1], t[2]} end)
        local f2 = Focus.new("f2", function(t) return {t[2], t[3]} end)
        assert.same({t3}, f1:onlyin(f2):get(all))
    end)

    it("fuzzy matches a field within the given edit distance", function()
        local tasks = {
            {vexid = "a", description = "buy fresh milk"},
            {vexid = "b", description = "walk the dog"},
        }
        local f = Focus.new("all", function(t) return t end)
        assert.same({tasks[1]}, f:fuzzy("description", "milc", 1):get(tasks))
    end)

    it("between keeps tasks whose field lies within the bounds", function()
        local tasks = {{vexid = "a", cost = 1}, {vexid = "b", cost = 5}, {vexid = "c", cost = 9}}
        local f = Focus.new("all", function(t) return t end)
        assert.same({tasks[2]}, f:between("cost", 2, 8):get(tasks))
        assert.same({tasks[2], tasks[3]}, f:between("cost", 2):get(tasks))
    end)

    it("between converts text bounds through the field's schema and skips tasks without the field", function()
        local task = require 'core.task'
        for _, properties in ipairs({
            {description = "between cheap task", cost = "2"},
            {description = "between pricey task", cost = "20"},
            {description = "between free task"},
        }) do
            local vexid = task:add(properties)
            task:resolve(vexid)
            task:write(vexid)
        end
        local result = Focus.focus('all'):between("cost", "1", "9"):get()
        assert.equal(1, #result)
        assert.equal("between cheap task", result[1].description)
    end)

    it("select keeps only the chosen fields plus the vexid", function()
        local f = Focus.new("all", function(t) return t end)
        assert.same({{vexid = "t1", status = "todo"}}, f:select("status"):get({{vexid = "t1", status = "todo", cost = 3}}))
    end)

    it("replays a saved focus with the same operations", function()
        local task = require 'core.task'
        for _, description in ipairs({"saved focus todo task", "saved focus doing task"}) do
            local vexid = task:add({description = description})
            task:resolve(vexid)
            task:write(vexid)
        end
        task:set("saved-focus-doing-task-1", {status = "doing"})
        task:resolve("saved-focus-doing-task-1")
        Focus.focus('all'):filter('status', 'doing'):fuzzy('description', 'saved focus', 0):write()
        local replayed = Focus.read():get()
        assert.equal(1, #replayed)
        assert.equal("saved-focus-doing-task-1", replayed[1].vexid)
    end)

    it("resolves a set operation's focus name and replays it once saved", function()
        local task = require 'core.task'
        for _, description in ipairs({"set op first task", "set op second task"}) do
            local vexid = task:add({description = description})
            task:resolve(vexid)
            task:write(vexid)
        end
        for _, operation in ipairs({'union', 'intersect', 'xor', 'notin', 'onlyin'}) do
            local parsed = Focus.parse({"set-op-first-task-1", {operation, "set-op-second-task-1"}})
            local expected = #parsed:get()
            parsed:write()
            assert.equal(expected, #Focus.read():get(), operation .. " did not replay")
        end
        assert.equal(2, #Focus.parse({"set-op-first-task-1", {"union", "set-op-second-task-1"}}):get())
    end)

    it("rejects parsing when the saved focus has nothing to replay", function()
        local cli = require 'lib.cli'
        local vexdex = require 'core.vexdex'
        stub(cli, 'throw', function(self, name) error(name) end)
        vexdex:setfocus({operations = {}})
        local ok, err = pcall(Focus.parse, {})
        cli.throw:revert()
        assert.is_false(ok)
        assert.truthy(err:find('no-focus', 1, true))
    end)

    describe("tree and reversetree", function()

        local root = {vexid = "root", children = {"mid"}}
        local mid = {vexid = "mid", children = {"leaf"}, dependencies = {"other"}}
        local leaf = {vexid = "leaf"}
        local other = {vexid = "other"}
        local linked = {root, mid, leaf, other}
        local orig

        local function vexids(tasks)
            local ids = {}
            for _, task in ipairs(tasks) do table.insert(ids, task.vexid) end
            return ids
        end

        before_each(function()
            orig = Focus.getalltasks
            Focus.getalltasks = function() return linked end
        end)

        after_each(function()
            Focus.getalltasks = orig
        end)

        it("tree collects each task and everything below it", function()
            local f = Focus.new("root", function() return {root} end)
            assert.same({"root", "mid", "leaf"}, vexids(f:tree('children'):get(linked)))
        end)

        it("tree tolerates tasks without the field", function()
            local f = Focus.new("leaf", function() return {leaf, other} end)
            assert.same({"leaf", "other"}, vexids(f:tree('children'):get(linked)))
        end)

        it("reversetree collects each task and everything above it", function()
            local f = Focus.new("leaf", function() return {leaf} end)
            assert.same({"leaf", "mid", "root"}, vexids(f:reversetree('children'):get(linked)))
        end)

        it("reversetree tolerates tasks without the field", function()
            local f = Focus.new("other", function() return {other} end)
            assert.same({"other", "mid"}, vexids(f:reversetree('dependencies'):get(linked)))
        end)

        it("backlinks collects the tasks that link to each task", function()
            local vexdex = require 'core.vexdex'
            vexdex:unsafe_link("mid", {"other"})
            local f = Focus.new("other", function() return {other} end)
            local result = vexids(f:backlinks():get(linked))
            vexdex:unsafe_remove("mid")
            assert.same({"mid"}, result)
        end)

    end)

end)
