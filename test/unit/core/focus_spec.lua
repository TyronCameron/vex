local event = require 'lib.event'
local Focus = require 'core.focus'
local func = require 'lib.func'
local cli = require 'lib.cli'

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

    it("nil keeps tasks that have no value for the field", function()
        local tasks = {{vexid = "a", cost = 1}, {vexid = "b"}, {vexid = "c", cost = 9}}
        local f = Focus.new("all", function(t) return t end)
        assert.same({tasks[2]}, f['nil'](f, "cost"):get(tasks))
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

    describe("interpret", function()

        local task = require 'core.task'
        local naturaltime = require 'lib.naturaltime'
        local soon, later

        setup(function()
            soon = task:add({description = "interpreted soon task", due = naturaltime.parse("tomorrow")})
            later = task:add({description = "interpreted later task", due = naturaltime.parse("in 3 years")})
            for _, vexid in ipairs({soon, later}) do
                task:resolve(vexid)
                task:write(vexid)
            end
        end)

        local function vexids(f)
            return func.imap(f:get(), function(t) return t.vexid end)
        end

        it("reads the next between's bounds as phrases relative to now", function()
            assert.same({soon}, vexids(Focus.focus('all'):interpret():between('due', 'now', 'next year')))
        end)

        it("reads the next filter's value as a phrase", function()
            assert.same({soon}, vexids(Focus.focus('all'):interpret():filter('due', 'tomorrow')))
        end)

        it("leaves an open bound open", function()
            assert.same({later}, vexids(Focus.focus('all'):interpret():between('due', 'next year', '')))
        end)

        it("applies to the next operation only", function()
            local f = Focus.focus('all'):interpret():filter('vextype', 'task')
            assert.is_nil(f.iso)
        end)

        it("replays from the saved focus", function()
            Focus.focus('all'):interpret():between('due', 'now', 'next year'):write()
            assert.same({soon}, vexids(Focus.read()))
        end)

        it("rejects a phrase it cannot interpret", function()
            local cli = require 'lib.cli'
            stub(cli, 'throw', function(self, name) error(name) end)
            local ok, err = pcall(function() Focus.focus('all'):interpret():filter('due', 'tomorrow blorp'):get() end)
            cli.throw:revert()
            assert.is_false(ok)
            assert.truthy(err:find('uninterpretable', 1, true))
        end)

    end)

    describe("ordering, grouping and numbering", function()

        local a = {vexid = "a", owner = "bob", cost = 3}
        local b = {vexid = "b", owner = "alice", cost = 1}
        local c = {vexid = "c", cost = 2}
        local d = {vexid = "d", owner = "bob"}
        local e = {vexid = "e", owner = "alice", cost = 1}
        local tasks = {a, b, c, d, e}
        local f = Focus.new("all", function(t) return t end)

        local function vexids(list)
            return func.imap(list, function(t) return t.vexid end)
        end

        it("orderby sorts by a field, keeping ties in order and missing values last", function()
            assert.same({"b", "e", "c", "a", "d"}, vexids(f:orderby('cost'):get(tasks)))
        end)

        it("orderby desc reverses the order and still puts missing values last", function()
            assert.same({"a", "c", "b", "e", "d"}, vexids(f:orderby('cost', 'desc'):get(tasks)))
        end)

        it("orderby breaks ties with the next field", function()
            assert.same({"e", "b", "c", "a", "d"}, vexids(f:orderby('cost', 'vexid', 'desc'):get(tasks)))
        end)

        it("groupby gathers tasks sharing a value, ordering the groups by it", function()
            assert.same({{"b", "e"}, {"a", "d"}, {"c"}}, func.imap(f:groupby('owner'):groups(tasks), vexids))
        end)

        it("groupby orders its groups descending, with missing values last", function()
            assert.same({{"a", "d"}, {"b", "e"}, {"c"}}, func.imap(f:groupby('owner', 'desc'):groups(tasks), vexids))
        end)

        it("groupby takes several fields", function()
            assert.same({{"b", "e"}, {"a"}, {"d"}, {"c"}}, func.imap(f:groupby('owner', 'cost'):groups(tasks), vexids))
        end)

        it("runs each later operation within each group, and get flattens the groups", function()
            assert.same({"e", "b", "d", "a", "c"}, vexids(f:groupby('owner'):orderby('vexid', 'desc'):get(tasks)))
            assert.same({{"b", "e"}}, func.imap(f:groupby('owner'):filter('cost', 1):groups(tasks), vexids))
        end)

        it("groups by several fields as it would by each in turn", function()
            local leaves = func.imap(f:groupby('owner'):groupby('cost'):groups(tasks), vexids)
            assert.same(func.imap(f:groupby('owner', 'cost'):groups(tasks), vexids), leaves)
        end)

        it("runs operations after a nested groupby within the innermost groups", function()
            local numbered = f:groupby('owner'):groupby('cost'):orderby('vexid', 'desc'):rn():get(tasks)
            assert.same({"e", "b", "a", "d", "c"}, vexids(numbered))
            assert.same({1, 2, 1, 1, 1}, func.imap(numbered, function(t) return t.rn end))
        end)

        it("first keeps the first n tasks in the order given", function()
            assert.same({"b", "e"}, vexids(f:orderby('cost'):first('2'):get(tasks)))
            assert.same({"a", "b"}, vexids(f:first(2):get(tasks)))
        end)

        it("last keeps the last n tasks without reversing them", function()
            assert.same({"a", "d"}, vexids(f:orderby('cost'):last('2'):get(tasks)))
        end)

        it("first and last return everything when n is larger than the list", function()
            assert.same({"a", "b", "c", "d", "e"}, vexids(f:first('99'):get(tasks)))
            assert.same({"a", "b", "c", "d", "e"}, vexids(f:last('99'):get(tasks)))
        end)

        it("first and last keep n tasks within each group", function()
            assert.same({"b", "a", "c"}, vexids(f:groupby('owner'):first('1'):get(tasks)))
            assert.same({"e", "d", "c"}, vexids(f:groupby('owner'):last('1'):get(tasks)))
        end)

        it("first and last reject an n that is not a positive whole number", function()
            stub(cli, 'throw', function(self, name) error(name) end)
            for _, operation in ipairs({'first', 'last'}) do
                for _, n in ipairs({'0', '-1', 'two', '1.5', ''}) do
                    local ok, err = pcall(function() f[operation](f, n) end)
                    assert.is_false(ok, operation .. ' ' .. n)
                    assert.truthy(err:find('usage', 1, true))
                end
                assert.is_false(pcall(function() f[operation](f) end))
            end
            cli.throw:revert()
        end)

        it("a saved first focus gives the same tasks", function()
            local task = require 'core.task'
            for _, properties in ipairs({{description = "limited first task"}, {description = "limited second task"}}) do
                local vexid = task:add(properties)
                task:resolve(vexid)
                task:write(vexid)
            end
            local limited = Focus.focus('all'):orderby('vexid'):last('1')
            limited:write()
            assert.same(vexids(limited:get()), vexids(Focus.read():get()))
            assert.equal(1, #Focus.read():get())
        end)

        it("a saved grouped focus gives the same groups", function()
            local task = require 'core.task'
            for _, properties in ipairs({{description = "grouped todo task"}, {description = "grouped doing task"}}) do
                local vexid = task:add(properties)
                task:resolve(vexid)
                task:write(vexid)
            end
            local grouped = Focus.focus('all'):groupby('status'):orderby('vexid')
            grouped:write()
            assert.same(func.imap(grouped:groups(), vexids), func.imap(Focus.read():groups(), vexids))
        end)

        it("rejects a flag that is not a focus operation", function()
            local cli = require 'lib.cli'
            stub(cli, 'throw', function(self, name) error(name) end)
            local ok, err = pcall(function() f:apply(cli:parse('--field owner')) end)
            cli.throw:revert()
            assert.is_false(ok)
            assert.truthy(err:find('unknown-focus-operation', 1, true))
        end)

        it("applies flags to a focus in the order given", function()
            local grouped = f:apply(require('lib.cli'):parse('--groupby owner --orderby cost:desc --rn')):get(tasks)
            assert.same({"b", "e", "a", "d", "c"}, vexids(grouped))
            assert.same({1, 2, 1, 2, 1}, func.imap(grouped, function(t) return t.rn end))
        end)

        it("rn numbers the tasks in each group from 1, without changing the tasks", function()
            local numbered = f:groupby('owner'):orderby('cost'):rn():get(tasks)
            assert.same({"b", "e", "a", "d", "c"}, vexids(numbered))
            assert.same({1, 2, 1, 2, 1}, func.imap(numbered, function(t) return t.rn end))
            assert.is_nil(b.rn)
        end)

        it("a set operation gathers the groups back into one", function()
            local none = Focus.new("none", function() return {} end)
            assert.same({"e", "d", "c", "b", "a"}, vexids(f:groupby('owner'):union(none):orderby('vexid', 'desc'):get(tasks)))
        end)

        it("interprets the next operation within each group", function()
            local dated = {{vexid = "x", owner = "bob", cost = 2}, {vexid = "y", owner = "alice", cost = 2}, {vexid = "z", owner = "alice", cost = 5}}
            assert.same({{"y"}, {"x"}}, func.imap(f:groupby('owner'):interpret():between('cost', '', 3):groups(dated), vexids))
        end)

        it("numbers saved tasks, keeping their transients, and replays from the saved focus", function()
            local task = require 'core.task'
            local first = task:add({description = "numbered first task", cost = 1})
            local second = task:add({description = "numbered second task", cost = 2})
            for _, vexid in ipairs({first, second}) do
                task:resolve(vexid)
                task:write(vexid)
            end
            Focus.focus(first):union(second):orderby('cost', 'desc'):rn():write()
            local replayed = Focus.read():get()
            assert.same({second, first}, vexids(replayed))
            assert.same({1, 2}, func.imap(replayed, function(t) return t.rn end))
            assert.equal(3, replayed[1].wordcount)
        end)

    end)

    it("select keeps only the chosen fields plus the vexid", function()
        local f = Focus.new("all", function(t) return t end)
        assert.same({{vexid = "t1", status = "todo"}}, f:select("status"):get({{vexid = "t1", status = "todo", cost = 3}}))
    end)

    it("filters and selects on a transient", function()
        local task = require 'core.task'
        local vexid = task:add({description = "focus on transient words"})
        task:resolve(vexid)
        task:write(vexid)
        local selected = Focus.focus('all'):filter('wordcount', 4):select('wordcount'):get()
        assert.same({{vexid = vexid, wordcount = 4}}, selected)
    end)

    it("replays a saved focus with the same operations", function()
        local task = require 'core.task'
        local vexids = {}
        for _, description in ipairs({"saved focus todo task", "saved focus finished task"}) do
            local vexid = task:add({description = description})
            task:resolve(vexid)
            task:write(vexid)
            table.insert(vexids, vexid)
        end
        task:set(vexids[2], {status = "done"})
        task:resolve(vexids[2])
        Focus.focus('all'):filter('status', 'done'):fuzzy('description', 'saved focus', 0):write()
        local replayed = Focus.read():get()
        assert.equal(1, #replayed)
        assert.equal(vexids[2], replayed[1].vexid)
    end)

    it("resolves a set operation's focus name and replays it once saved", function()
        local task = require 'core.task'
        for _, description in ipairs({"set op first task", "set op second task"}) do
            local vexid = task:add({description = description})
            task:resolve(vexid)
            task:write(vexid)
        end
        for _, operation in ipairs({'union', 'intersect', 'xor', 'notin', 'onlyin'}) do
            local parsed = Focus.parse(cli:parse("set-op-first-task-1 --" .. operation .. " set-op-second-task-1"))
            local expected = #parsed:get()
            parsed:write()
            assert.equal(expected, #Focus.read():get(), operation .. " did not replay")
        end
        assert.equal(2, #Focus.parse(cli:parse("set-op-first-task-1 --union set-op-second-task-1")):get())
    end)

    describe("lists of names", function()

        local task = require 'core.task'
        local first, second

        setup(function()
            for _, description in ipairs({"listed first task", "listed second task"}) do
                local vexid = task:add({description = description})
                task:resolve(vexid)
                task:write(vexid)
            end
            first, second = "listed-first-task-1", "listed-second-task-1"
        end)

        local function vexids(f)
            local result = {}
            f:each(function(vexid) table.insert(result, vexid) end)
            table.sort(result)
            return result
        end

        it("unions every name given to Focus.focus", function()
            assert.same({first, second}, vexids(Focus.focus(first, second)))
        end)

        it("unions a list of names and replays it once saved", function()
            Focus.focus({first, second}):write()
            assert.same({first, second}, vexids(Focus.read()))
        end)

        it("parses a comma list of names from the CLI", function()
            assert.same({first, second}, vexids(Focus.parse(cli:parse(first .. "," .. second))))
        end)

        it("selects every field in a comma list from the CLI", function()
            local selected = Focus.parse(cli:parse(first .. " --select status,wordcount")):get()
            assert.same({{vexid = first, status = "todo", wordcount = 3}}, selected)
        end)

    end)

    it("rejects parsing when the saved focus has nothing to replay", function()
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

        it("tree visits each task once on a cycle", function()
            local first = {vexid = "first", children = {"second"}}
            local second = {vexid = "second", children = {"first"}}
            Focus.getalltasks = function() return {first, second} end
            local f = Focus.new("first", function() return {first} end)
            assert.same({"first", "second"}, vexids(f:tree('children'):get()))
        end)

        it("reversetree collects each task and everything above it", function()
            local f = Focus.new("leaf", function() return {leaf} end)
            assert.same({"leaf", "mid", "root"}, vexids(f:reversetree('children'):get(linked)))
        end)

        it("tree and reversetree follow several fields at once", function()
            local decision = {vexid = "decision", options = {"option"}}
            local option = {vexid = "option"}
            local both = {root, decision, option}
            Focus.getalltasks = function() return both end
            local f = Focus.new("decision", function() return {decision} end)
            assert.same({"decision", "option"}, vexids(f:tree('children', 'options'):get()))
            local g = Focus.new("option", function() return {option} end)
            assert.same({"option", "decision"}, vexids(g:reversetree('children', 'options'):get()))
        end)

        it("tree and reversetree follow forwardlinks like any other field", function()
            local hub = {vexid = "hub", forwardlinks = {"leaf", "other"}}
            local spoke = {vexid = "leaf", forwardlinks = {}}
            local far = {vexid = "other", forwardlinks = {}}
            Focus.getalltasks = function() return {hub, spoke, far} end
            local f = Focus.new("hub", function() return {hub} end)
            assert.same({"hub", "leaf", "other"}, vexids(f:tree('forwardlinks'):get()))
            local g = Focus.new("leaf", function() return {spoke} end)
            assert.same({"leaf", "hub"}, vexids(g:reversetree('forwardlinks'):get()))
        end)

        it("reversetree tolerates tasks without the field", function()
            local f = Focus.new("other", function() return {other} end)
            assert.same({"other", "mid"}, vexids(f:reversetree('dependencies'):get(linked)))
        end)

        it("step moves one hop along a field", function()
            local f = Focus.new("root", function() return {root} end)
            assert.same({"mid"}, vexids(f:step('children'):get(linked)))
            assert.same({"leaf"}, vexids(f:step('children'):step('children'):get(linked)))
        end)

        it("step follows several fields, visits each task once and skips ids that match no task", function()
            local twin = {vexid = "twin", children = {"leaf", "ghost"}, dependencies = {"other"}}
            local both = {mid, twin, leaf, other}
            Focus.getalltasks = function() return both end
            local f = Focus.new("both", function() return {mid, twin} end)
            assert.same({"leaf", "other"}, vexids(f:step('children', 'dependencies'):get()))
        end)

        it("tree, reversetree and step need a field", function()
            stub(cli, 'throw', function(self, name) error(name) end)
            local f = Focus.new("root", function() return {root} end)
            for _, operation in ipairs({'tree', 'reversetree', 'step'}) do
                local ok, err = pcall(function() return f[operation](f) end)
                assert.is_false(ok)
                assert.truthy(err:find('usage', 1, true))
            end
            cli.throw:revert()
        end)

        it("step follows forwardlinks like any other field", function()
            local hub = {vexid = "hub", forwardlinks = {"other", "leaf"}}
            Focus.getalltasks = function() return {hub, leaf, other} end
            local f = Focus.new("hub", function() return {hub} end)
            assert.same({"other", "leaf"}, vexids(f:step('forwardlinks'):get()))
        end)

    end)

    it("fires pre- and post-focus-write with the focus being saved", function()
        local fired = {}
        for _, name in ipairs {'pre-focus-write', 'post-focus-write'} do
            event:register(name, 'spec', function(...) fired[name] = {...} end)
        end
        local f = Focus.focus('all')
        f:write()
        for _, name in ipairs {'pre-focus-write', 'post-focus-write'} do event:remove(name, 'spec') end
        assert.same({f}, fired['pre-focus-write'])
        assert.same({f}, fired['post-focus-write'])
    end)

end)
