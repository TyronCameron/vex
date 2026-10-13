local busted = require 'busted'
local cli = require 'lib.cli'
local task = require 'core.task'
require 'core.taskdefinitions'

describe("taskdefinitions", function()

    before_each(function()
        stub(cli, 'throw', function(self, name) error(name) end)
    end)

    after_each(function()
        cli.throw:revert()
    end)

    local function create(properties)
        local vexid = task:add(properties)
        task:resolve(vexid)
        task:write(vexid)
        return vexid
    end

    local function setstatus(vexid, status)
        task:set(vexid, {status = status})
        task:resolve(vexid)
        task:write(vexid)
    end

    describe("status", function()

        it("defaults a new task to todo", function()
            local vexid = create({description = "status default task"})
            assert.equal("todo", task.tasks[vexid].status)
        end)

        it("allows todo to doing to done", function()
            local vexid = create({description = "status forward task"})
            setstatus(vexid, "doing")
            setstatus(vexid, "done")
            assert.equal("done", task.tasks[vexid].status)
        end)

        it("rejects todo to done", function()
            local vexid = create({description = "status skipping task"})
            task:set(vexid, {status = "done"})
            assert.has_error(function() task:resolve(vexid) end)
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', vexid, match._)
        end)

        it("rejects doing back to todo", function()
            local vexid = create({description = "status backward task"})
            setstatus(vexid, "doing")
            task:set(vexid, {status = "todo"})
            assert.has_error(function() task:resolve(vexid) end)
        end)

        it("accepts an unchanged status and does not leak it to other tasks", function()
            local done = create({description = "status finished task"})
            setstatus(done, "doing")
            setstatus(done, "done")
            local todo = create({description = "status untouched task"})
            task:resolve(done)
            task:resolve(todo)
            assert.equal("done", task.tasks[done].status)
            assert.equal("todo", task.tasks[todo].status)
        end)

    end)

end)
