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
