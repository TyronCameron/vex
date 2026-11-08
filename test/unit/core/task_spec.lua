local task = require 'core.task'
local vexdex = require 'core.vexdex'
local event = require 'lib.event'
local func = require 'lib.func'
local schema = require 'lib.schema'
require 'core.taskdefinitions'

local function create(properties)
    local vexid = task:add(properties)
    task:resolve(vexid)
    task:writeall()
    return vexid
end

local function copy(tab)
    local result = {}
    for k, v in pairs(tab) do result[k] = type(v) == "table" and copy(v) or v end
    return result
end

local function comparable(t)
    local result = copy(t)
    result.modified = nil
    result.vexbody = result.vexbody or ""
    return result
end

describe("task", function()

    it("add inserts a task into memory without writing to disk", function()
        local vexid = task:add({description = "test task for spec tests"})
        assert.truthy(vexid)
        assert.is_table(task.tasks[vexid])
        task:remove(vexid)
    end)

    it("add gives a task the config's default tasktype when it has none", function()
        local config = require 'core.config'
        local default = config.properties.default
        config.properties.default = {tasktype = 'atom'}
        local vexid = task:add({description = "default typed task"})
        config.properties.default = default
        assert.equal('atom', task.tasks[vexid].vextype)
        task:remove(vexid)
    end)

    it("add gives two tasks with one description different vexids before either resolves", function()
        local first = task:add({description = "twice added chore"})
        local second = task:add({description = "twice added chore"})
        assert.equal("twice-added-chore-1", first)
        assert.equal("twice-added-chore-2", second)
        task:remove(first)
        task:remove(second)
    end)

    it("tells a type's date fields from its other fields", function()
        assert.is_true(task:isdatefield('task', 'due'))
        assert.is_true(task:isdatefield('task', 'created'))
        assert.is_false(task:isdatefield('task', 'cost'))
        assert.is_false(task:isdatefield('task', 'nosuchfield'))
    end)

    describe("recur", function()

        it("adds the next task with the over date moved on by the recurrence and an initial status", function()
            local vexid = create({description = "recurring spec chore", recur = 'weekly', due = 1000000, vexbody = "same body"})
            task:set(vexid, {status = 'done'})
            local successor = task:recur(vexid)
            local next = task.tasks[successor]
            assert.equal("recurring-spec-chore-2", successor)
            assert.equal('todo', next.status)
            assert.equal('weekly', next.recur)
            assert.equal(1000000 + 7 * 86400, next.due)
            assert.equal("same body", next.vexbody)
            assert.is_true(next.created >= task.tasks[vexid].created)
        end)

        it("recurs from now when the over field is empty", function()
            local vexid = create({description = "undated recurring chore", recur = 'daily'})
            local before = os.time()
            local next = task.tasks[task:recur(vexid)]
            assert.is_true(next.due >= before + 86400 and next.due <= os.time() + 86400)
        end)

        it("adds the next task when a recurring task resolves into a final phase, and only then", function()
            local vexid = create({description = "resolved recurring chore", recur = 'weekly', due = 1000000})
            local successor = "resolved-recurring-chore-2"
            task:set(vexid, {cost = 1})
            task:resolve(vexid)
            assert.is_nil(task.tasks[successor])
            task:set(vexid, {status = 'done'})
            task:resolve(vexid)
            task:writeall()
            assert.equal(1000000 + 7 * 86400, task.tasks[successor].due)
            task:resolve(vexid)
            assert.is_nil(task.tasks["resolved-recurring-chore-3"])
        end)

        it("puts the next task among its parent's children", function()
            local child = create({description = "parented recurring chore", recur = 'daily'})
            local parent = create({description = "recurring chores parent", vextype = 'abstract', children = {child}})
            local successor = task:recur(child)
            task:writeall()
            assert.same({child, successor}, task.tasks[parent].children)
        end)

    end)

    it("set updates fields on an in-memory task", function()
        local vexid = task:add({description = "another test task for set"})
        task:set(vexid, {status = "done"})
        assert.equal("done", task.tasks[vexid].status)
        task:remove(vexid)
    end)

    it("set leaves the indexed version of a task untouched", function()
        local vexid = task:add({description = "indexed task for set"})
        task:resolve(vexid)
        task:set(vexid, {status = "done"})
        assert.equal("todo", vexdex:get(vexid).status)
        assert.equal("done", task.tasks[vexid].status)
        vexdex:unsafe_remove(vexid)
        task:remove(vexid)
    end)

    describe("set with modifiers", function()

        local parent, first, second

        before_each(function()
            first = create({description = "modified first child"})
            second = create({description = "modified second child"})
            parent = create({description = "modified parent abstract", vextype = 'abstract', children = {first}})
        end)

        it("inserts values into a list without overwriting it, skipping ones already there", function()
            task:set(parent, {children = {second, first}}, {children = 'insert'})
            assert.same({first, second}, task.tasks[parent].children)
        end)

        it("inserts a single value", function()
            task:set(parent, {children = second}, {children = 'insert'})
            assert.same({first, second}, task.tasks[parent].children)
        end)

        it("inserts into a field the task does not hold yet", function()
            task:set(first, {dependencies = second}, {dependencies = 'insert'})
            assert.same({second}, task.tasks[first].dependencies)
        end)

        it("removes values from a list by value", function()
            task:set(parent, {children = {first, second}})
            task:set(parent, {children = first}, {children = 'remove'})
            assert.same({second}, task.tasks[parent].children)
        end)

        it("clears a field", function()
            task:set(parent, {}, {children = 'clear'})
            assert.is_nil(task.tasks[parent].children)
        end)

        it("rejects clearing a field and giving it a value", function()
            local cli = require 'lib.cli'
            stub(cli, 'throw', function(self, name) error(name) end)
            local ok, err = pcall(task.set, task, parent, {children = second}, {children = 'clear'})
            cli.throw:revert()
            assert.is_false(ok)
            assert.truthy(err:find('clear-with-value', 1, true))
        end)

        it("shows lists as the YAML written to the file", function()
            task:set(parent, {children = {first, second}})
            task:resolve(parent)
            task:writeall()
            assert.truthy(task:show(parent):find('\n  - "[[' .. first .. ']]"\n  - "[[' .. second .. ']]"\n', 1, true))
            task:set(parent, {children = {}})
            task:resolve(parent)
            task:writeall()
            assert.truthy(task:show(parent):find('[]\n', 1, true))
        end)

        it("rejects an unknown modifier", function()
            local cli = require 'lib.cli'
            stub(cli, 'throw', function(self, name) error(name) end)
            local ok, err = pcall(task.set, task, parent, {children = second}, {children = 'append'})
            cli.throw:revert()
            assert.is_false(ok)
            assert.truthy(err:find('unknown-modifier', 1, true))
        end)

    end)

    it("gets list fields joined with commas", function()
        local child = create({description = "gotten list child"})
        local other = create({description = "gotten list other"})
        local parent = create({description = "gotten list parent", vextype = 'abstract', children = {child, other}})
        assert.equal("[[" .. child .. "]],[[" .. other .. "]]", task:get(parent, {'children'}))
    end)

    it("remove strips the vexid from tasks linking to it and rewrites them", function()
        local child = create({description = "cascaded child task"})
        local parent = create({description = "cascading parent abstract", vextype = 'abstract', children = {child}})
        local dependent = create({description = "cascading dependent task", dependencies = {child}})
        task:remove(child)
        task:delete(child)
        task:writeall()
        assert.same({}, task.tasks[parent].children)
        assert.same({}, task.tasks[dependent].dependencies)
        assert.same({}, task:read(parent).children)
        assert.same({}, task:read(dependent).dependencies)
    end)

    it("delete leaves the file until writeall removes it", function()
        local vexid = create({description = "deferred deleted task"})
        local path = task:getcurrentpath(vexid)
        task:remove(vexid)
        task:delete(vexid)
        assert.truthy(io.open(path))
        task:writeall()
        assert.is_nil(io.open(path))
    end)

    it("writeall keeps a deleted task's file when a write fails", function()
        local deleted = create({description = "deleted before failed write"})
        local kept = create({description = "kept through failed write"})
        local path = task:getcurrentpath(deleted)
        task:remove(deleted)
        task:delete(deleted)
        task:set(kept, {cost = 2})
        task:resolve(kept)
        local atomic = vexdex.atomic
        vexdex.atomic = function() error("write failed") end
        local ok = pcall(task.writeall, task)
        vexdex.atomic = atomic
        assert.is_false(ok)
        assert.truthy(io.open(path))
        task:writeall()
        assert.is_nil(io.open(path))
    end)

    it("remove deletes the task entry from memory", function()
        local vexid = task:add({description = "task to be removed by spec"})
        task:remove(vexid)
        assert.is_nil(task.tasks[vexid])
    end)

    describe("disk round-trip", function()

        local function roundtrip(vexid)
            local resolved = comparable(task.tasks[vexid])
            task.tasks[vexid] = nil
            task:read(vexid)
            task:resolve(vexid)
            assert.same(resolved, comparable(task.tasks[vexid]))
        end

        it("reads back every field of a task as resolved", function()
            local before = create({description = "roundtrip dependency task"})
            roundtrip(create({
                description = "roundtrip full task",
                due = "2026-08-01 09:00:00",
                cost = "15",
                benefit = "40",
                vexbody = "Some notes\nover two lines",
                dependencies = {before},
            }))
        end)

        it("reads back an abstract with its children", function()
            local child = create({description = "roundtrip child task"})
            roundtrip(create({description = "roundtrip parent abstract", vextype = 'abstract', children = {child}}))
        end)

        it("reads back an atom", function()
            roundtrip(create({description = "roundtrip atom task", vextype = 'atom'}))
        end)

        it("reads back a decision with its options and decision", function()
            local first = create({description = "roundtrip first option"})
            local second = create({description = "roundtrip second option"})
            roundtrip(create({description = "roundtrip decision task", vextype = 'decision', options = {first, second}, decision = second}))
        end)

        it("resolves to the same task when resolved again", function()
            local vexid = create({description = "resolved twice task", cost = "3"})
            local resolved = comparable(task.tasks[vexid])
            task:resolve(vexid)
            assert.same(resolved, comparable(task.tasks[vexid]))
        end)

    end)

    it("reading a task from disk unformats it", function()
        local dependency = create({description = "read dependency task"})
        local vexid = create({description = "indexed then read task", dependencies = {dependency}})
        vexdex:unsafe_remove(vexid)
        task.tasks[vexid] = nil
        local read = task:read(vexid)
        assert.is_number(read.created)
        assert.same({dependency}, read.dependencies)
    end)

    it("runs each prevalidate step once per resolve", function()
        local schema = require 'lib.schema'
        local calls = 0
        task:task 'countedtype':extends 'task' {
            schema = schema.atleast {
                counted = schema.derive {
                    schema.num,
                    derive = function() calls = calls + 1 return calls end
                }
            }
        }
        local vexid = task:add({description = "counted prevalidate task", vextype = 'countedtype'})
        task:resolve(vexid)
        assert.equal(1, calls)
    end)

    it("resolves a type two levels below task through every ancestor's schema", function()
        local schema = require 'lib.schema'
        task:task 'grandchildtype':extends 'atom' { schema = schema.atleast { tier = schema.default {schema.num, default = function() return 3 end} } }
        local vexid = task:add({description = "grandchild typed task", vextype = 'grandchildtype'})
        task:resolve(vexid)
        assert.equal(3, task.tasks[vexid].tier)
        assert.equal('todo', task.tasks[vexid].status)
    end)

    it("validates a field a type redefines by the type's own rule, not its ancestor's", function()
        local schema = require 'lib.schema'
        task:task 'loosecost':extends 'atom' { schema = schema.atleast { cost = schema.maybe {schema.str} } }
        local cli = require 'lib.cli'
        stub(cli, 'throw', function(self, name) error(name) end)
        local vexid = task:add({description = "loosely costed task", vextype = 'loosecost', cost = "a lot"})
        local ok, err = pcall(function() task:resolve(vexid) end)
        cli.throw:revert()
        assert.is_true(ok, err)
        assert.equal("a lot", task.tasks[vexid].cost)
    end)

    it("lets an ancestor's derived field read a field its descendant defaults", function()
        local schema = require 'lib.schema'
        schema.register 'echoedmood' {
            validate = function() return true end,
            postvalidate = function(self, instance, context) return context.root.mood end
        }
        task:task 'echoparent':extends 'atom' { schema = schema.atleast { echo = schema.echoedmood } }
        task:task 'echochild':extends 'echoparent' {
            schema = schema.atleast { mood = schema.default {schema.str, default = function() return 'calm' end} }
        }
        local vexid = task:add({description = "echoed mood task", vextype = 'echochild'})
        task:resolve(vexid)
        assert.equal('calm', task.tasks[vexid].echo)
    end)

    describe("transients", function()

        local schema = require 'lib.schema'
        task:task 'transientparent':extends 'task' { schema = schema.atleast {} }
        task:task 'transientchild':extends 'transientparent' { schema = schema.atleast {} }
        task:transient 'shout' { vextype = 'transientparent', definition = function(t) return t.description:upper() end }
        task:transient 'loud' { vextype = 'transientparent', definition = function(t) return t.shout .. '!' end }
        task:transient 'kind' { vextype = 'transientparent', definition = function() return 'parent' end }
        task:transient 'kind' { vextype = 'transientchild', definition = function() return 'child' end }
        task:transient 'createdtype' { vextype = 'transientparent', definition = function(t) return type(t.created) end }

        it("computes a transient on a task as soon as it is added", function()
            local vexid = task:add({description = "quiet added task", vextype = 'transientparent'})
            assert.equal("QUIET ADDED TASK", task.tasks[vexid].shout)
            task:remove(vexid)
        end)

        it("lets a transient use another transient", function()
            local vexid = task:add({description = "quiet chained task", vextype = 'transientparent'})
            assert.equal("QUIET CHAINED TASK!", task.tasks[vexid].loud)
            task:remove(vexid)
        end)

        it("never stores a transient on the task, in the index or in the file", function()
            local vexid = create({description = "quiet stored task", vextype = 'transientparent'})
            assert.equal("QUIET STORED TASK", vexdex:get(vexid).shout)
            for field in pairs(task.tasks[vexid]) do assert.not_equal('shout', field) end
            assert.is_nil(io.open(task:getabspath(vexid)):read("*a"):find("shout", 1, true))
        end)

        it("inherits transients from parent types and lets a subtype override them", function()
            local parent = task:add({description = "quiet parent type task", vextype = 'transientparent'})
            local child = task:add({description = "quiet child type task", vextype = 'transientchild'})
            local plain = task:add({description = "quiet plain type task"})
            assert.equal("QUIET CHILD TYPE TASK", task.tasks[child].shout)
            assert.equal("parent", task.tasks[parent].kind)
            assert.equal("child", task.tasks[child].kind)
            assert.is_nil(task.tasks[plain].shout)
            task:remove(parent)
            task:remove(child)
            task:remove(plain)
        end)

        it("prefers a stored field over a transient of the same name", function()
            local vexid = create({description = "quiet shadowed task", vextype = 'transientparent', shout = "whisper"})
            assert.equal("whisper", task.tasks[vexid].shout)
        end)

        it("gets a transient computed from the unformatted task", function()
            local vexid = create({description = "quiet gotten task", vextype = 'transientparent'})
            assert.equal("QUIET GOTTEN TASK\tnumber", task:get(vexid, {'shout', 'createdtype'}))
        end)

        it("rejects a transient for a task type that does not exist", function()
            assert.has_error(function()
                task:transient 'orphaned' { vextype = 'nosuchtype', definition = function() end }
            end)
        end)

    end)

    it("reindexall rebuilds the index from the task files, including hand edits", function()
        local vexid = create({description = "hand edited task"})
        local path = task:getabspath(vexid)
        local content = io.open(path):read("*a"):gsub("\nstatus: todo\n", "\nstatus: todo\ncost: 7\n")
        local f = io.open(path, "w")
        f:write(content)
        f:close()
        vexdex:unsafe_remove(vexid)
        task.tasks = {}
        task:reindexall()
        assert.equal(7, vexdex:get(vexid).cost)
    end)

    describe("changes", function()

        local OLD = 1577836800

        local function backdated(properties)
            local vexid = create(properties)
            task:set(vexid, {modified = OLD})
            task:resolve(vexid)
            task:writeall()
            return vexid
        end

        local function contents(vexid)
            local f = io.open(task:getcurrentpath(vexid))
            local content = f:read("*a")
            f:close()
            return content
        end

        it("leaves modified alone when resolving a task changes nothing but modified", function()
            local vexid = backdated({description = "unchanged backdated task"})
            assert.equal(OLD, task.tasks[vexid].modified)
            task:set(vexid, {cost = task.tasks[vexid].cost})
            task:resolve(vexid)
            assert.equal(OLD, task.tasks[vexid].modified)
        end)

        it("moves modified when resolving a task whose content changed", function()
            local vexid = backdated({description = "changed backdated task"})
            task:set(vexid, {cost = 3})
            task:resolve(vexid)
            assert.is_true(task.tasks[vexid].modified > OLD)
        end)

        it("leaves the file alone until writeall writes the resolved task back to it", function()
            local vexid = backdated({description = "written backdated task"})
            task:set(vexid, {cost = 4})
            task:resolve(vexid)
            assert.is_nil(contents(vexid):find("cost:"))
            task:writeall()
            assert.equal(4, task:readfrompath(task:getcurrentpath(vexid)).cost)
        end)

        it("writes a task that changed on an earlier resolve even when a later one leaves it unchanged", function()
            local vexid = backdated({description = "twice resolved backdated task"})
            task:set(vexid, {cost = 5})
            task:resolve(vexid)
            task:resolve(vexid)
            task:writeall()
            assert.equal(5, task:readfrompath(task:getcurrentpath(vexid)).cost)
        end)

        it("does not rewrite a task that resolving leaves unchanged", function()
            local vexid = backdated({description = "untouched backdated task"})
            local writes = 0
            local atomic = vexdex.atomic
            vexdex.atomic = function(self, path, ...)
                if path == task:getcurrentpath(vexid) then writes = writes + 1 end
                return atomic(self, path, ...)
            end
            task:resolve(vexid)
            task:writeall()
            vexdex.atomic = atomic
            assert.equal(0, writes)
            assert.truthy(contents(vexid):find("modified: \"2020%-01%-01"))
        end)

    end)

    describe("files changed on disk", function()

        local function edit(vexid, from, to)
            local path = task:getcurrentpath(vexid)
            local f = io.open(path)
            local content = f:read("*a")
            f:close()
            f = io.open(path, "w")
            f:write((content:gsub(from, to)))
            f:close()
        end

        it("resolves a hand-edited task into the index and moves its modified", function()
            local vexid = create({description = "resolved hand edited task"})
            task:set(vexid, {modified = 1577836800})
            task:resolve(vexid)
            edit(vexid, "\nstatus: todo\n", "\nstatus: todo\ncost: 3\n")
            task.tasks[vexid] = nil
            task:resolve(vexid)
            assert.equal(3, vexdex:get(vexid).cost)
            assert.is_true(vexdex:get(vexid).modified > 1577836800)
        end)

        it("drops a task whose file is unreadable from the index, leaving the file", function()
            local vexid = create({description = "dropped broken hand edited task"})
            local path = task:getcurrentpath(vexid)
            edit(vexid, "^%-%-%-\n", "")
            task.tasks[vexid] = nil
            task:resolve(vexid)
            assert.is_nil(vexdex:get(vexid))
            assert.truthy(io.open(path))
            os.remove(path)
        end)

        it("resolves the tasks linked to a task whose file is gone", function()
            local child = create({description = "gone linked child task"})
            local parent = create({description = "gone linking parent abstract", vextype = 'abstract', children = {child}})
            os.remove(task:getcurrentpath(parent))
            task.tasks[parent] = nil
            local resolved = {}
            event:register('pre-task-resolve', 'gone-spec', function(vexid) resolved[vexid] = true end)
            task:resolve(parent)
            event:remove('pre-task-resolve', 'gone-spec')
            assert.is_nil(vexdex:get(parent))
            assert.truthy(resolved[child])
        end)

        it("takes in a new task file and the files that changed, but not the others", function()
            local edited = create({description = "reindexed edited task"})
            local kept = create({description = "reindexed kept task"})
            edit(edited, "\nstatus: todo\n", "\nstatus: todo\ncost: 4\n")
            task.tasks[edited] = nil
            local path = vexdex:taskroot() .. "/made-by-hand-1.md"
            local f = io.open(path, "w")
            f:write("---\nvexid: made-by-hand-1\ndescription: Made by hand\nvextype: task\n---\n")
            f:close()
            local resolved = {}
            event:register('pre-task-resolve', 'reindex-spec', function(vexid) resolved[vexid] = true end)
            task:reindexall()
            event:remove('pre-task-resolve', 'reindex-spec')
            assert.same({[edited] = true, ["made-by-hand-1"] = true}, resolved)
            assert.equal(4, vexdex:get(edited).cost)
            assert.is_nil(resolved[kept])
            task:remove("made-by-hand-1")
            task:delete("made-by-hand-1")
            task:writeall()
        end)

    end)

    describe("cascading resolution", function()

        task:task 'tracker':extends 'atom' {
            schema = schema.atleast {
                openblockers = schema.derive {
                    schema.maybe {schema.num},
                    derive = function(self, instance, context) return #context.task.blockers end
                }
            }
        }

        local function finish(vexid)
            task:set(vexid, {status = "done"})
            task:resolve(vexid)
            task:writeall()
        end

        it("re-derives the stored fields of the tasks linked to a resolved task", function()
            local dependency = create({description = "cascade dependency task", vextype = 'atom'})
            local tracker = create({description = "cascade tracking task", vextype = 'tracker', dependencies = {dependency}})
            assert.equal(1, task.tasks[tracker].openblockers)
            finish(dependency)
            assert.equal(0, task.tasks[tracker].openblockers)
            assert.equal(0, vexdex:get(tracker).openblockers)
            assert.equal(0, task:readfrompath(task:getcurrentpath(tracker)).openblockers)
        end)

        it("also resolves the tasks a resolved task stopped linking to", function()
            local first = create({description = "cascade unlinked first", vextype = 'atom'})
            local second = create({description = "cascade unlinked second", vextype = 'atom', dependencies = {first}})
            task:set(second, {dependencies = {}})
            local resolved = {}
            event:register('pre-task-resolve', 'cascade-spec', function(vexid) resolved[vexid] = true end)
            task:resolve(second)
            event:remove('pre-task-resolve', 'cascade-spec')
            assert.same({[first] = true, [second] = true}, resolved)
        end)

        local function resolving(vexid)
            local resolved = {}
            event:register('pre-task-resolve', 'cascade-spec', function(id) resolved[id] = (resolved[id] or 0) + 1 end)
            task:resolve(vexid)
            event:remove('pre-task-resolve', 'cascade-spec')
            return resolved
        end

        it("resolves each linked task once when the task changed", function()
            local first = create({description = "cascade chain first", vextype = 'atom'})
            local second = create({description = "cascade chain second", vextype = 'atom', dependencies = {first}})
            local third = create({description = "cascade chain third", vextype = 'atom', dependencies = {second}})
            task:set(second, {cost = 7})
            assert.same({[first] = 1, [second] = 1, [third] = 1}, resolving(second))
        end)

        it("resolves only the task itself when it is unchanged", function()
            local first = create({description = "cascade clean first", vextype = 'atom'})
            local second = create({description = "cascade clean second", vextype = 'atom', dependencies = {first}})
            create({description = "cascade clean third", vextype = 'atom', dependencies = {second}})
            assert.same({[second] = 1}, resolving(second))
        end)

        it("stops at a linked task that did not change", function()
            local first = create({description = "cascade stop first", vextype = 'atom'})
            local second = create({description = "cascade stop second", vextype = 'atom', dependencies = {first}})
            local third = create({description = "cascade stop third", vextype = 'atom', dependencies = {second}})
            task:set(first, {cost = 9})
            local resolved = resolving(first)
            assert.equal(1, resolved[second])
            assert.is_nil(resolved[third])
        end)

    end)

    describe("events", function()

        local fired

        before_each(function()
            fired = {}
            event:register('*', 'spec', function(name, ...)
                fired[name] = fired[name] or {}
                table.insert(fired[name], {...})
            end)
        end)

        after_each(function()
            event:remove('*', 'spec')
        end)

        it("fires pre- and post-task-add with the properties, then the vexid and task", function()
            local properties = {description = "evented added task"}
            local vexid = task:add(properties)
            assert.equal(properties, fired['pre-task-add'][1][1])
            assert.equal(vexid, fired['post-task-add'][1][1])
            assert.equal(task.tasks[vexid], fired['post-task-add'][1][2])
            task:remove(vexid)
        end)

        it("fires pre- and post-task-set with the changes, then the new task", function()
            local vexid = create({description = "evented set task"})
            local properties, modifiers = {cost = 3}, {}
            task:set(vexid, properties, modifiers)
            assert.same({vexid, properties, modifiers}, fired['pre-task-set'][1])
            assert.same({vexid, task.tasks[vexid]}, fired['post-task-set'][1])
        end)

        it("fires pre- and post-task-resolve with the vexid, then the resolved task and the task as last indexed", function()
            local vexid = task:add({description = "evented resolved task"})
            task:resolve(vexid)
            assert.same({vexid}, fired['pre-task-resolve'][1])
            assert.equal(vexid, fired['post-task-resolve'][1][1])
            assert.equal(task.tasks[vexid], fired['post-task-resolve'][1][2])
            assert.same({}, fired['post-task-resolve'][1][3])
            local indexed = vexdex:get(vexid)
            task:set(vexid, {cost = 2})
            task:resolve(vexid)
            assert.equal(indexed, fired['post-task-resolve'][2][3])
        end)

        it("fires pre- and post-task-write with the vexid, then the path written", function()
            task:writeall()
            fired = {}
            local vexid = create({description = "evented written task"})
            assert.same({vexid}, fired['pre-task-write'][1])
            assert.same({vexid, task:getcurrentpath(vexid)}, fired['post-task-write'][1])
        end)

        it("fires pre- and post-task-move with the vexid, then where the file moved from and to", function()
            local vexid = create({description = "evented moved task"})
            fired = {}
            task:move(vexid)
            assert.same({vexid}, fired['pre-task-move'][1])
            assert.same({vexid, task:getabspath(vexid), task:getabspath(vexid)}, fired['post-task-move'][1])
        end)

        it("fires pre- and post-task-get and task-show with what was asked and the result", function()
            local vexid = create({description = "evented gotten task"})
            local got = task:get(vexid, {'vexid'})
            local shown = task:show(vexid)
            assert.same({vexid, {'vexid'}}, fired['pre-task-get'][1])
            assert.same({vexid, {'vexid'}, got}, fired['post-task-get'][1])
            assert.same({vexid}, fired['pre-task-show'][1])
            assert.same({vexid, shown}, fired['post-task-show'][1])
        end)

        it("fires pre- and post-task-remove and task-delete with the vexid, then the deleted path", function()
            local vexid = create({description = "evented deleted task"})
            local path = task:getcurrentpath(vexid)
            task:remove(vexid)
            task:delete(vexid)
            assert.same({vexid}, fired['pre-task-remove'][1])
            assert.same({vexid}, fired['post-task-remove'][1])
            assert.same({vexid}, fired['pre-task-delete'][1])
            assert.same({vexid, path}, fired['post-task-delete'][1])
        end)

        it("fires pre- and post-task-reindexall, and task-read for each file read when forced", function()
            local vexid = create({description = "evented reindexed task"})
            local path = task:getcurrentpath(vexid)
            task:reindexall(true)
            assert.same({true}, fired['pre-task-reindexall'][1])
            assert.same({true}, fired['post-task-reindexall'][1])
            assert.truthy(func.any(fired['pre-task-read'], function(args) return args[1] == path end))
            assert.truthy(func.any(fired['post-task-read'], function(args)
                return args[1] == path and args[2] and args[2].vexid == vexid
            end))
        end)

    end)

    describe("reading", function()

        local function plain(s)
            return (s:gsub("\27%[[%d;]*m", ""):gsub("\27%]8;;.-\27\\", ""))
        end

        it("keeps the body in the task file only", function()
            local vexid = create({description = "body kept in file task", vexbody = "kept in the file"})
            assert.is_nil(rawget(vexdex:get(vexid), 'vexbody'))
            assert.is_nil(vexdex.new(vexdex.path):get(vexid).vexbody)
            task.tasks[vexid] = nil
            assert.equal("kept in the file", task:getsingle(vexid).vexbody)
        end)

        it("shows the task file as it is on disk", function()
            local vexid = create({description = "shown from file task", vexbody = "kept in the file"})
            local path = task:getcurrentpath(vexid)
            local f = assert(io.open(path, "a"))
            f:write("\nhand written line\n")
            f:close()
            local shown = plain(task:show(vexid))
            assert.truthy(shown:find("kept in the file\nhand written line\n", 1, true), shown)
            assert.truthy(shown:find("vexid: " .. vexid, 1, true))
        end)

        it("gets the task as last committed to the index, not as set in memory", function()
            local vexid = create({description = "committed cost task", cost = 3})
            task:set(vexid, {cost = 9})
            assert.equal("3", task:get(vexid, {'cost'}))
            task:resolve(vexid)
            task:writeall()
            assert.equal("9", task:get(vexid, {'cost'}))
        end)

        it("commits the index with the files in writeall", function()
            local vexid = create({description = "committed index task", cost = 4})
            assert.equal(4, vexdex.new(vexdex.path):get(vexid).cost)
        end)

    end)

    describe("reading and rebuilding", function()

        local function handmade(properties)
            local vexid = create(properties)
            local path = task:getabspath(vexid)
            vexdex:unsafe_remove(vexid)
            task.tasks = {}
            return vexid, path
        end

        it("reading a task file does not put the task in the index", function()
            local vexid, path = handmade({description = "read but not indexed task"})
            assert.equal(vexid, task:read(vexid).vexid)
            assert.is_nil(vexdex:get(vexid))
            os.remove(path)
        end)

        it("reindexall ignores a file it cannot read or that holds no vexid", function()
            local files = {
                [vexdex.path .. "/broken-unreadable-1.md"] = "---\nvexid: broken-unreadable-1\ndescription: never closed\n",
                [vexdex.path .. "/Buy groceries.md"] = "---\ntitle: Buy groceries\nstatus: todo\n---\n",
            }
            for path, content in pairs(files) do
                local f = io.open(path, "w")
                f:write(content)
                f:close()
            end
            local cli = require 'lib.cli'
            stub(cli, 'throw', function(_, name) error(name) end)
            local ok = pcall(task.reindexall, task)
            cli.throw:revert()
            for path in pairs(files) do os.remove(path) end
            assert.is_true(ok)
            assert.is_nil(vexdex:get("broken-unreadable-1"))
        end)

        it("reindexall ignores a markdown file that is not a task", function()
            local notes = vexdex.path .. "/notes-not-a-task.md"
            local f = io.open(notes, "w")
            f:write("just some notes\n")
            f:close()
            task:reindexall()
            os.remove(notes)
            assert.is_nil(vexdex:get("notes-not-a-task"))
        end)

        it("reindexall refuses two files holding the same vexid, naming both", function()
            local cli = require 'lib.cli'
            local vexid, path = handmade({description = "task held by two files"})
            local copy = vexdex.path .. "/copy-of-" .. vexid .. ".md"
            local original = io.open(path):read("*a")
            local f = io.open(copy, "w")
            f:write(original)
            f:close()
            stub(cli, 'throw', function(_, name, id, first, second) error(table.concat({name, id, first, second}, "|")) end)
            local ok, err = pcall(task.reindexall, task)
            cli.throw:revert()
            os.remove(copy)
            task:reindexall()
            assert.is_false(ok)
            assert.truthy(err:find("duplicate-vexid|" .. vexid, 1, true))
            assert.truthy(err:find("copy-of-" .. vexid .. ".md", 1, true))
            assert.truthy(err:find("/" .. vexid .. ".md", 1, true))
        end)

    end)

end)
