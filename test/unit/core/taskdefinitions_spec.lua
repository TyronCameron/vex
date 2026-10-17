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

        it("records backlinks when resolving", function()
            local vexdex = require 'core.vexdex'
            local child = create({description = "backlinked child task"})
            local parent = create({description = "backlinking parent abstract", vextype = 'abstract', children = {child}})
            local dependent = create({description = "backlinking dependent task", dependencies = {child}})
            assert.truthy(vexdex.backlinks[child][parent])
            assert.truthy(vexdex.backlinks[child][dependent])
        end)

        it("rejects a link to a task that does not exist", function()
            local dependent = task:add({description = "dependent on nothing real", dependencies = {"no-such-task-1"}})
            assert.has_error(function() task:resolve(dependent) end)
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', dependent, match._)
        end)

        it("rejects dependency cycles", function()
            local first = create({description = "cycle first task"})
            local second = create({description = "cycle second task", dependencies = {first}})
            task:set(first, {dependencies = {second}})
            assert.has_error(function() task:resolve(first) end)
            assert.stub(cli.throw).was.called_with(cli, 'dependency-cycle', first, second)
        end)

    end)

    describe("transients", function()

        it("counts the words in the description", function()
            local vexid = task:add({description = "count  these four words"})
            assert.equal(4, task.tasks[vexid].wordcount)
            task:remove(vexid)
        end)

        it("places the status in its phase of the state machine", function()
            local vexid = create({description = "phased task"})
            assert.equal("initial", task.tasks[vexid].phase)
            setstatus(vexid, "doing")
            assert.equal("interim", task.tasks[vexid].phase)
            setstatus(vexid, "done")
            assert.equal("final", task.tasks[vexid].phase)
        end)

        it("lists a task's ancestors, nearest first", function()
            local child = create({description = "ancestry child task"})
            local parent = create({description = "ancestry parent abstract", vextype = 'abstract', children = {child}})
            local grandparent = create({description = "ancestry grandparent abstract", vextype = 'abstract', children = {parent}})
            assert.same({parent, grandparent}, task.tasks[child].ancestors)
            assert.same({}, task.tasks[grandparent].ancestors)
        end)

        it("gives a task that is not indexed yet no ancestors", function()
            local vexid = task:add({description = "unindexed ancestry task"})
            assert.same({}, task.tasks[vexid].ancestors)
            task:remove(vexid)
        end)

        it("gives the path of the task file", function()
            local vexid = create({description = "located task"})
            assert.equal(task:getabspath(vexid), task.tasks[vexid].path)
        end)

        it("gives the task's age in whole days, once it has been created", function()
            local fresh = task:add({description = "unresolved aged task"})
            assert.is_nil(task.tasks[fresh].age)
            task:remove(fresh)
            local vexid = create({description = "aged task", created = os.time() - 3 * 86400 - 60})
            assert.equal(3, task.tasks[vexid].age)
        end)

    end)

end)
