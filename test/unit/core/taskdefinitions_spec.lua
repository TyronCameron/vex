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

    describe("links", function()

        it("writes children and dependencies as links", function()
            local child = create({description = "formatted link child"})
            local parent = create({description = "formatted link parent", vextype = 'abstract', children = {child}})
            local dependent = create({description = "formatted link dependent", dependencies = {child}})
            assert.same({"[[" .. child .. "]]"}, task:format(parent).children)
            assert.same({"[[" .. child .. "]]"}, task:format(dependent).dependencies)
        end)

        it("lets a parent resolve again with its own children", function()
            local child = create({description = "only child task"})
            local parent = create({description = "only parent abstract", vextype = 'abstract', children = {child}})
            task:resolve(parent)
            assert.stub(cli.throw).was_not.called()
        end)

        it("rejects a task in two abstracts' children", function()
            local child = create({description = "shared child task"})
            create({description = "first parent abstract", vextype = 'abstract', children = {child}})
            local second = task:add({description = "second parent abstract", vextype = 'abstract', children = {child}})
            assert.has_error(function() task:resolve(second) end)
            assert.stub(cli.throw).was.called_with(cli, 'multiple-parents', child, second, match._)
        end)

        it("rejects dependency cycles", function()
            local first = create({description = "cycle first task"})
            local second = create({description = "cycle second task", dependencies = {first}})
            task:set(first, {dependencies = {second}})
            assert.has_error(function() task:resolve(first) end)
            assert.stub(cli.throw).was.called_with(cli, 'dependency-cycle', first, second)
        end)

    end)

end)
