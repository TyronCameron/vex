local busted = require 'busted'
local task = require 'core.task'

describe("task", function()

    it("singleton loads and is a table", function()
        assert.is_table(task)
    end)

    it("task.fields is a table", function()
        assert.is_table(task.fields)
    end)

    it("task.tasks is a table", function()
        assert.is_table(task.tasks)
    end)

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
        local vexdex = require 'core.vexdex'
        local vexid = task:add({description = "indexed task for set"})
        task:resolve(vexid)
        task:set(vexid, {status = "doing"})
        assert.equal("todo", vexdex:get(vexid).status)
        assert.equal("doing", task.tasks[vexid].status)
        vexdex:unsafe_remove(vexid)
        task:remove(vexid)
    end)

    it("remove strips the vexid from tasks linking to it and rewrites them", function()
        local function create(properties)
            local vexid = task:add(properties)
            task:resolve(vexid)
            task:write(vexid)
            return vexid
        end
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

    it("registertask adds a new task type", function()
        task:registertask("__spectype1", nil, {schema = {}, fields = {}})
        assert.truthy(task.tasktypes["__spectype1"])
    end)

end)
