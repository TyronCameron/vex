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

    it("withtransients merges a derived value without mutating the stored task", function()
        task:transient '__spec_double' {
            derive = function(t, context) return (t.cost or 0) * 2 end
        }
        local vexid = task:add({description = "task for transient spec", cost = 5})
        local merged = task:withtransients(task.tasks[vexid])
        assert.equal(10, merged.__spec_double)
        assert.is_nil(task.tasks[vexid].__spec_double)
        task:remove(vexid)
    end)

    it("descendants counts all tasks transitively reachable via children", function()
        local grandchild = task:add({description = "spec grandchild task", vextype = "atom"})
        task:resolve(grandchild)
        local child1 = task:add({description = "spec child task one", vextype = "abstract"})
        task:set(child1, {children = {grandchild}})
        task:resolve(child1)
        local child2 = task:add({description = "spec child task two", vextype = "atom"})
        task:resolve(child2)
        local parent = task:add({description = "spec parent task", vextype = "abstract"})
        task:set(parent, {children = {child1, child2}})
        task:resolve(parent)

        assert.equal(3, task:withtransients(task.tasks[parent]).descendants)
        assert.equal(1, task:withtransients(task.tasks[child1]).descendants)
        assert.equal(0, task:withtransients(task.tasks[child2]).descendants)

        task:remove(grandchild)
        task:remove(child1)
        task:remove(child2)
        task:remove(parent)
    end)

end)
