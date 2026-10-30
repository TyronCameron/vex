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
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', vexid, match._, match._)
        end)

        it("reports the failing status as a failure with its message first", function()
            local vexid = create({description = "status failure task"})
            task:set(vexid, {status = "done"})
            assert.has_error(function() task:resolve(vexid) end)
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', vexid, match.is_truthy(), match._)
            local failure = cli.throw.calls[#cli.throw.calls].vals[4]
            assert.truthy(tostring(failure):find("Cannot transition status from todo to done", 1, true))
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
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', dependent, match._, match._)
        end)

        it("rejects dependency cycles", function()
            local first = create({description = "cycle first task"})
            local second = create({description = "cycle second task", dependencies = {first}})
            task:set(first, {dependencies = {second}})
            assert.has_error(function() task:resolve(first) end)
            assert.stub(cli.throw).was.called_with(cli, 'dependency-cycle', first, second)
        end)

        it("rejects a dependency on a task with children", function()
            local child = create({description = "grouped leaf task"})
            local parent = create({description = "depended on abstract", vextype = 'abstract', children = {child}})
            local dependent = task:add({description = "depending on abstract task", dependencies = {parent}})
            assert.has_error(function() task:resolve(dependent) end)
            assert.stub(cli.throw).was.called_with(cli, 'dependency-with-children', dependent, parent)
        end)

        it("rejects a dependency on a task with options", function()
            local option = create({description = "optional leaf task"})
            local decision = create({description = "depended on decision", vextype = 'decision', options = {option}})
            local dependent = task:add({description = "depending on decision task", dependencies = {decision}})
            assert.has_error(function() task:resolve(dependent) end)
            assert.stub(cli.throw).was.called_with(cli, 'dependency-with-children', dependent, decision)
        end)

    end)

    describe("link sets per task type", function()

        local function rejected(properties)
            local vexid = task:add(properties)
            assert.has_error(function() task:resolve(vexid) end)
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', vexid, match._, match._)
        end

        it("lets an atom depend on an atom", function()
            local first = create({description = "atom dependency first", vextype = 'atom'})
            local second = create({description = "atom dependency second", vextype = 'atom', dependencies = {first}})
            assert.same({first}, task.tasks[second].dependencies)
        end)

        it("gives abstracts only children", function()
            local other = create({description = "abstract link target"})
            rejected({description = "abstract with dependencies", vextype = 'abstract', dependencies = {other}})
            rejected({description = "abstract with options", vextype = 'abstract', options = {other}})
        end)

        it("gives decisions only options", function()
            local other = create({description = "decision link target"})
            rejected({description = "decision with children", vextype = 'decision', options = {other}, children = {other}})
            rejected({description = "decision with dependencies", vextype = 'decision', options = {other}, dependencies = {other}})
        end)

        it("gives atoms only dependencies", function()
            local other = create({description = "atom link target"})
            rejected({description = "atom with children", vextype = 'atom', children = {other}})
            rejected({description = "atom with options", vextype = 'atom', options = {other}})
        end)

        it("gives explorations no children or options", function()
            local other = create({description = "exploration link target"})
            rejected({description = "exploration with children", vextype = 'exploration', children = {other}})
            rejected({description = "exploration with options", vextype = 'exploration', options = {other}})
        end)

    end)

    describe("task types", function()

        it("all extend basetask", function()
            for _, name in ipairs({'task', 'abstract', 'decision', 'exploration', 'atom'}) do
                assert.equal('basetask', task.tasktypes[name].parent, name)
            end
        end)

        it("gives every type but abstract a status machine", function()
            for _, name in ipairs({'task', 'decision', 'exploration', 'atom'}) do
                assert.truthy(task:schemaof(name, 'status'), name)
            end
            assert.is_nil(task:schemaof('abstract', 'status'))
        end)

    end)

    describe("abstract status", function()

        it("is never stored", function()
            local child = create({description = "unstored status child"})
            local parent = create({description = "unstored status abstract", vextype = 'abstract', children = {child}})
            setstatus(child, "doing")
            assert.is_nil(rawget(task.tasks[parent], 'status'))
            assert.equal("doing", task.tasks[parent].status)
        end)

        it("is stored as todo, doing or done according to the children", function()
            local first = create({description = "derived status first"})
            local second = create({description = "derived status second"})
            local parent = create({description = "derived status abstract", vextype = 'abstract', children = {first, second}})
            assert.equal("todo", task.tasks[parent].status)
            setstatus(first, "doing")
            assert.equal("doing", task.tasks[parent].status)
            setstatus(first, "done")
            assert.equal("doing", task.tasks[parent].status)
            setstatus(second, "doing")
            setstatus(second, "done")
            assert.equal("done", task.tasks[parent].status)
        end)

        it("follows a child's status up through nested abstracts", function()
            local leaf = create({description = "nested status leaf"})
            local inner = create({description = "nested status inner", vextype = 'abstract', children = {leaf}})
            local outer = create({description = "nested status outer", vextype = 'abstract', children = {inner}})
            setstatus(leaf, "doing")
            assert.equal("doing", task.tasks[outer].status)
            setstatus(leaf, "done")
            assert.equal("done", task.tasks[outer].status)
        end)

        it("moves back when a finished child is taken away", function()
            local first = create({description = "taken away first"})
            local second = create({description = "taken away second"})
            local parent = create({description = "taken away abstract", vextype = 'abstract', children = {first, second}})
            setstatus(first, "doing")
            setstatus(first, "done")
            task:set(parent, {children = {second}})
            task:resolve(parent)
            assert.equal("todo", task.tasks[parent].status)
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

        it("places an abstract's phase from the phases of its children", function()
            local first = create({description = "derived phase first"})
            local second = create({description = "derived phase second"})
            local parent = create({description = "derived phase abstract", vextype = 'abstract', children = {first, second}})
            assert.equal("initial", task.tasks[parent].phase)
            setstatus(first, "doing")
            assert.equal("interim", task.tasks[parent].phase)
            setstatus(first, "done")
            assert.equal("interim", task.tasks[parent].phase)
            setstatus(second, "doing")
            setstatus(second, "done")
            assert.equal("final", task.tasks[parent].phase)
        end)

        it("lists the dependencies that are not final as the task's blockers", function()
            local first = create({description = "blocking first task"})
            local second = create({description = "blocking second task"})
            local blocked = create({description = "blocked task", dependencies = {first, second}})
            local free = create({description = "unblocked task"})
            assert.same({first, second}, task.tasks[blocked].blockers)
            assert.same({}, task.tasks[free].blockers)
            setstatus(first, "doing")
            assert.same({first, second}, task.tasks[blocked].blockers)
            setstatus(first, "done")
            assert.same({second}, task.tasks[blocked].blockers)
            setstatus(second, "doing")
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
            setstatus(finished, "doing")
            setstatus(finished, "done")
            assert.equal(1, task.tasks[sooner].urgency)
            assert.equal(2, task.tasks[later].urgency)
            assert.truthy(task.tasks[undated].urgency > 2)
            assert.is_nil(task.tasks[finished].urgency)
        end)

    end)

end)
