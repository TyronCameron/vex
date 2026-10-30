local task = require 'core.task'
local vexdex = require 'core.vexdex'
local event = require 'lib.event'
local func = require 'lib.func'

local function create(properties)
    local vexid = task:add(properties)
    task:resolve(vexid)
    task:write(vexid)
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
        assert.same({}, task.tasks[parent].children)
        assert.same({}, task.tasks[dependent].dependencies)
        assert.same({}, task:read(parent).children)
        assert.same({}, task:read(dependent).dependencies)
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

    it("reading a task from disk indexes it unformatted", function()
        local dependency = create({description = "read dependency task"})
        local vexid = create({description = "indexed then read task", dependencies = {dependency}})
        vexdex:unsafe_remove(vexid)
        task.tasks[vexid] = nil
        task:read(vexid)
        assert.is_number(vexdex:get(vexid).created)
        assert.same({dependency}, vexdex:get(vexid).dependencies)
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

        it("fires pre- and post-task-resolve with the vexid, then the resolved task", function()
            local vexid = task:add({description = "evented resolved task"})
            task:resolve(vexid)
            assert.same({vexid}, fired['pre-task-resolve'][1])
            assert.equal(vexid, fired['post-task-resolve'][1][1])
            assert.equal(task.tasks[vexid], fired['post-task-resolve'][1][2])
        end)

        it("fires pre- and post-task-write with the vexid, then the path written", function()
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

        it("fires pre- and post-task-reindexall, and task-read for each file read", function()
            local vexid = create({description = "evented reindexed task"})
            local path = task:getcurrentpath(vexid)
            task:reindexall()
            assert.same({}, fired['pre-task-reindexall'][1])
            assert.same({}, fired['post-task-reindexall'][1])
            assert.truthy(func.any(fired['pre-task-read'], function(args) return args[1] == path end))
            assert.truthy(func.any(fired['post-task-read'], function(args)
                return args[1] == path and args[2] and args[2].vexid == vexid
            end))
        end)

    end)

end)
