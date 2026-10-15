local task = require 'core.task'
local vexdex = require 'core.vexdex'

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

    it("set updates fields on an in-memory task", function()
        local vexid = task:add({description = "another test task for set"})
        task:set(vexid, {status = "done"})
        assert.equal("done", task.tasks[vexid].status)
        task:remove(vexid)
    end)

    it("set leaves the indexed version of a task untouched", function()
        local vexid = task:add({description = "indexed task for set"})
        task:resolve(vexid)
        task:set(vexid, {status = "doing"})
        assert.equal("todo", vexdex:get(vexid).status)
        assert.equal("doing", task.tasks[vexid].status)
        vexdex:unsafe_remove(vexid)
        task:remove(vexid)
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

        it("reads back a decision with its options and decision (fix-decision-constraint-crashing-1)", function()
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

end)
