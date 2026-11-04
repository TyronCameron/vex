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

        it("allows a task to go from todo to done", function()
            local vexid = create({description = "status forward task"})
            setstatus(vexid, "done")
            assert.equal("done", task.tasks[vexid].status)
        end)

        it("rejects doing on a task, which only has todo and done", function()
            local vexid = create({description = "status doing task"})
            task:set(vexid, {status = "doing"})
            assert.has_error(function() task:resolve(vexid) end)
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', vexid, match._, match._)
        end)

        it("reports the failing status as a failure with its message first", function()
            local vexid = create({description = "status failure task"})
            setstatus(vexid, "done")
            task:set(vexid, {status = "todo"})
            assert.has_error(function() task:resolve(vexid) end)
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', vexid, match.is_truthy(), match._)
            local failure = cli.throw.calls[#cli.throw.calls].vals[4]
            assert.truthy(tostring(failure):find("Cannot transition status from done to todo", 1, true))
        end)

        it("accepts an unchanged status and does not leak it to other tasks", function()
            local done = create({description = "status finished task"})
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
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', dependent, match._, match._)
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
            setstatus(vexid, "done")
            assert.equal("final", task.tasks[vexid].phase)
        end)

        it("lists the dependencies that are not final as the task's blockers", function()
            local first = create({description = "blocking first task"})
            local second = create({description = "blocking second task"})
            local blocked = create({description = "blocked task", dependencies = {first, second}})
            local free = create({description = "unblocked task"})
            assert.same({first, second}, task.tasks[blocked].blockers)
            assert.same({}, task.tasks[free].blockers)
            setstatus(first, "done")
            assert.same({second}, task.tasks[blocked].blockers)
            setstatus(second, "done")
            assert.same({}, task.tasks[blocked].blockers)
        end)

        it("lists a task's lineage, root first", function()
            local child = create({description = "ancestry child task"})
            local parent = create({description = "ancestry parent abstract", vextype = 'abstract', children = {child}})
            local grandparent = create({description = "ancestry grandparent abstract", vextype = 'abstract', children = {parent}})
            assert.same({grandparent, parent}, task.tasks[child].lineage)
            assert.same({}, task.tasks[grandparent].lineage)
        end)

        it("counts a decision as the parent of its options", function()
            local option = create({description = "decision option task"})
            local decision = create({description = "decision with option", vextype = 'decision', options = {option}})
            assert.equal(decision, task.tasks[option].parent)
            assert.same({decision}, task.tasks[option].lineage)
        end)

        it("gives a task's parent, and nothing for a root", function()
            local child = create({description = "parented child task"})
            local parent = create({description = "parented parent abstract", vextype = 'abstract', children = {child}})
            assert.equal(parent, task.tasks[child].parent)
            assert.is_nil(task.tasks[parent].parent)
        end)

        it("lists the tasks linking to a task as its backlinks and the tasks it links to as its forwardlinks", function()
            local child = create({description = "linked child task"})
            local needed = create({description = "linked needed task"})
            local parent = create({description = "linked parent abstract", vextype = 'abstract', children = {child}})
            local dependent = create({description = "linked dependent task", dependencies = {child, needed}})
            local function sorted(...) local list = {...} table.sort(list) return list end
            assert.same(sorted(parent, dependent), task.tasks[child].backlinks)
            assert.same(sorted(child, needed), task.tasks[dependent].forwardlinks)
            assert.same({}, task.tasks[parent].backlinks)
            assert.same({child}, task.tasks[parent].forwardlinks)
            assert.same({}, task.tasks[needed].forwardlinks)
        end)

        it("lists every link a decision holds once as its forwardlinks", function()
            local option = create({description = "forward option task"})
            local decision = create({description = "forward decision task", vextype = 'decision', options = {option}, decision = option})
            assert.same({option}, task.tasks[decision].forwardlinks)
        end)

        it("gives the path of the task file", function()
            local vexid = create({description = "located task"})
            assert.equal(task:getcurrentpath(vexid), task.tasks[vexid].path)
        end)

        it("gives the task's age in whole days, once it has been created", function()
            local fresh = task:add({description = "unresolved aged task"})
            assert.is_nil(task.tasks[fresh].age)
            task:remove(fresh)
            local vexid = create({description = "aged task", created = os.time() - 3 * 86400 - 60})
            assert.equal(3, task.tasks[vexid].age)
        end)

        it("ranks each open task by how soon it is due, as its urgency", function()
            local later = create({description = "urgent later task", due = os.time() + 7 * 86400})
            local sooner = create({description = "urgent sooner task", due = os.time() + 86400})
            local undated = create({description = "urgent undated task"})
            local finished = create({description = "urgent finished task", due = os.time()})
            setstatus(finished, "done")
            assert.equal(1, task.tasks[sooner].urgency)
            assert.equal(2, task.tasks[later].urgency)
            assert.truthy(task.tasks[undated].urgency > 2)
            assert.is_nil(task.tasks[finished].urgency)
        end)

        it("ranks a dependency by the due date of the open tasks that depend on it", function()
            local base = os.time() + 30 * 86400
            local needed = create({description = "pulled needed task", due = base + 20 * 86400})
            local unrelated = create({description = "pulled unrelated task", due = base + 10 * 86400})
            create({description = "pulled dependent task", due = base, dependencies = {needed}})
            assert.equal(base, task.tasks[needed].implied_due)
            assert.truthy(task.tasks[needed].urgency < task.tasks[unrelated].urgency)
        end)

        it("ranks an undated dependency ahead of an unrelated dated task when a dated task needs it", function()
            local needed = create({description = "undated needed task"})
            local unrelated = create({description = "dated unrelated task", due = os.time() + 90 * 86400})
            create({description = "dated needing task", due = os.time() + 60 * 86400, dependencies = {needed}})
            assert.truthy(task.tasks[needed].urgency < task.tasks[unrelated].urgency)
        end)

        it("carries a due date down a chain of dependents", function()
            local due = os.time() + 3 * 86400
            local bottom = create({description = "chained bottom task"})
            local middle = create({description = "chained middle task", dependencies = {bottom}})
            create({description = "chained top task", due = due, dependencies = {middle}})
            assert.equal(due, task.tasks[middle].implied_due)
            assert.equal(due, task.tasks[bottom].implied_due)
        end)

        it("ignores finished dependents when working out its implied due date", function()
            local needed = create({description = "ignored needed task", due = os.time() + 40 * 86400})
            local dependent = create({description = "ignored dependent task", due = os.time() + 86400, dependencies = {needed}})
            setstatus(dependent, "done")
            assert.equal(task.tasks[needed].due, task.tasks[needed].implied_due)
        end)

    end)

end)
