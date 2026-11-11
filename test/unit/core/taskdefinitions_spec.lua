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

        it("writes the parent and dependencies as links", function()
            local parent = create({description = "formatted link parent", vextype = 'abstract'})
            local child = create({description = "formatted link child", parent = parent})
            local dependent = create({description = "formatted link dependent", dependencies = {child}})
            assert.equal("[[" .. parent .. "]]", task:format(child).parent)
            assert.same({"[[" .. child .. "]]"}, task:format(dependent).dependencies)
        end)

        it("lets a parent resolve again with its own children", function()
            local parent = create({description = "only parent abstract", vextype = 'abstract'})
            create({description = "only child task", parent = parent})
            task:resolve(parent)
            assert.stub(cli.throw).was_not.called()
        end)

        it("records backlinks when resolving", function()
            local vexdex = require 'core.vexdex'
            local parent = create({description = "backlinking parent abstract", vextype = 'abstract'})
            local child = create({description = "backlinked child task", parent = parent})
            local dependent = create({description = "backlinking dependent task", dependencies = {child}})
            assert.truthy(vexdex.backlinks[parent][child])
            assert.truthy(vexdex.backlinks[child][dependent])
        end)

        it("rejects a task as its own parent", function()
            local vexid = create({description = "self parent task"})
            task:set(vexid, {parent = vexid})
            assert.has_error(function() task:resolve(vexid) end)
            assert.stub(cli.throw).was.called_with(cli, 'parent-cycle', vexid, vexid)
        end)

        it("rejects parent cycles", function()
            local first = create({description = "parent cycle first", vextype = 'abstract'})
            local second = create({description = "parent cycle second", vextype = 'abstract', parent = first})
            task:set(first, {parent = second})
            assert.has_error(function() task:resolve(first) end)
            assert.stub(cli.throw).was.called_with(cli, 'parent-cycle', first, second)
        end)

        it("rejects a parent that another task depends on", function()
            local needed = create({description = "depended parent task"})
            local dependent = create({description = "depending on parent task", dependencies = {needed}})
            local child = task:add({description = "late child task", parent = needed})
            assert.has_error(function() task:resolve(child) end)
            assert.stub(cli.throw).was.called_with(cli, 'dependency-with-children', dependent, needed)
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

        it("allows a due date from the latest dependency's to the earliest dependent's, equal dates included", function()
            local base = os.time() + 10 * 86400
            local needed = create({description = "bounded needed task", due = base})
            local task_ = create({description = "bounded middle task", due = base + 86400, dependencies = {needed}})
            create({description = "bounded needing task", due = base + 86400, dependencies = {task_}})
            task:set(task_, {due = base + 86400 / 2})
            task:resolve(task_)
            assert.stub(cli.throw).was_not.called_with(cli, 'due-out-of-order', match._, match._)
        end)

        it("rejects a due date earlier than a dependency's", function()
            local base = os.time() + 10 * 86400
            local needed = create({description = "early needed task", due = base})
            local dependent = task:add({description = "too early dependent", due = base - 86400, dependencies = {needed}})
            assert.has_error(function() task:resolve(dependent) end)
            assert.stub(cli.throw).was.called_with(cli, 'due-out-of-order', dependent, needed)
        end)

        it("rejects a due date later than a dependent's", function()
            local base = os.time() + 10 * 86400
            local needed = create({description = "late needed task", due = base})
            local dependent = create({description = "late needing task", due = base + 86400, dependencies = {needed}})
            task:set(needed, {due = base + 2 * 86400})
            assert.has_error(function() task:resolve(needed) end)
            assert.stub(cli.throw).was.called_with(cli, 'due-out-of-order', dependent, needed)
        end)

        it("ignores undated and finished neighbours when checking a due date", function()
            local base = os.time() + 10 * 86400
            local finished = create({description = "finished late task", due = base + 5 * 86400})
            setstatus(finished, "done")
            local undated = create({description = "undated neighbour task"})
            local checked = create({description = "checked neighbour task", due = base, dependencies = {finished, undated}})
            assert.truthy(task.tasks[checked])
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
            local grandparent = create({description = "ancestry grandparent abstract", vextype = 'abstract'})
            local parent = create({description = "ancestry parent abstract", vextype = 'abstract', parent = grandparent})
            local child = create({description = "ancestry child task", parent = parent})
            assert.same({grandparent, parent}, task.tasks[child].lineage)
            assert.same({}, task.tasks[grandparent].lineage)
        end)

        it("lists the tasks whose parent is a task as its children", function()
            local parent = create({description = "childed parent abstract", vextype = 'abstract'})
            local first = create({description = "childed first task", parent = parent})
            local second = create({description = "childed second task", parent = parent})
            create({description = "childed dependent task", dependencies = {first}})
            local function sorted(...) local list = {...} table.sort(list) return list end
            assert.same(sorted(first, second), task.tasks[parent].children)
            assert.is_nil(task.tasks[first].children)
        end)

        it("lists the tasks linking to a task as its backlinks and the tasks it links to as its forwardlinks", function()
            local parent = create({description = "linked parent abstract", vextype = 'abstract'})
            local child = create({description = "linked child task", parent = parent})
            local needed = create({description = "linked needed task"})
            local dependent = create({description = "linked dependent task", dependencies = {child, needed}})
            local function sorted(...) local list = {...} table.sort(list) return list end
            assert.same({dependent}, task.tasks[child].backlinks)
            assert.same({parent}, task.tasks[child].forwardlinks)
            assert.same(sorted(child, needed), task.tasks[dependent].forwardlinks)
            assert.same({child}, task.tasks[parent].backlinks)
            assert.same({}, task.tasks[parent].forwardlinks)
            assert.same({}, task.tasks[needed].forwardlinks)
        end)

        it("lists the tasks that depend on a task as its dependents, and not its children", function()
            local needed = create({description = "depended needed task", vextype = 'abstract'})
            create({description = "depended child task", parent = needed})
            local leaf = create({description = "depended leaf task"})
            local dependent = create({description = "depended dependent task", dependencies = {leaf}})
            assert.same({dependent}, task.tasks[leaf].dependents)
            assert.same({}, task.tasks[needed].dependents)
        end)

        it("puts a task that has no status yet in the initial phase", function()
            local fresh = task:add({description = "statusless fresh task"})
            assert.equal('initial', task.tasks[fresh].phase)
            task:remove(fresh)
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

        it("keeps a dated task's own due date", function()
            local due = os.time() + 3 * 86400
            local dated = create({description = "kept dated task", due = due})
            create({description = "kept later dependent", due = due + 86400, dependencies = {dated}})
            assert.equal(due, task.tasks[dated].due)
        end)

        it("defaults an undated task's due to the earliest due of the open tasks that depend on it", function()
            local due = os.time() + 3 * 86400
            local needed = create({description = "defaulted needed task"})
            local sooner = create({description = "defaulted sooner needing task", due = due})
            local later = create({description = "defaulted later needing task", due = due + 86400})
            task:set(sooner, {dependencies = {needed}})
            task:resolve(sooner)
            task:set(later, {dependencies = {needed}})
            task:resolve(later)
            assert.equal(due, task.tasks[needed].due)
        end)

        it("carries a due date down a chain of undated dependencies", function()
            local due = os.time() + 3 * 86400
            local bottom = create({description = "chained bottom task"})
            local middle = create({description = "chained middle task", dependencies = {bottom}})
            create({description = "chained top task", due = due, dependencies = {middle}})
            assert.equal(due, task.tasks[middle].due)
            assert.equal(due, task.tasks[bottom].due)
        end)

        it("leaves due empty when no open dependent has one", function()
            local finished = create({description = "empty finished dependent", due = os.time() + 86400})
            setstatus(finished, "done")
            local needed = create({description = "empty needed task"})
            task:set(finished, {dependencies = {needed}})
            task:resolve(finished)
            assert.is_nil(task.tasks[needed].due)
            local lonely = create({description = "empty lonely task"})
            assert.is_nil(task.tasks[lonely].due)
        end)

        it("ranks an undated dependency ahead of an unrelated dated task when a dated task needs it", function()
            local needed = create({description = "undated needed task"})
            local unrelated = create({description = "dated unrelated task", due = os.time() + 90 * 86400})
            create({description = "dated needing task", due = os.time() + 60 * 86400, dependencies = {needed}})
            assert.truthy(task.tasks[needed].urgency < task.tasks[unrelated].urgency)
        end)

        it("gives tasks with the same due the same urgency", function()
            local due = os.time() + 5 * 86400
            local first = create({description = "tied first task", due = due})
            local second = create({description = "tied second task", due = due})
            local later = create({description = "tied later task", due = due + 86400})
            assert.equal(task.tasks[first].urgency, task.tasks[second].urgency)
            assert.equal(task.tasks[first].urgency + 2, task.tasks[later].urgency)
        end)

    end)

    describe("tags", function()
        local config = require 'core.config'

        after_each(function()
            config.properties.autotags = nil
        end)

        it("leaves tags unset without rules or manual tags", function()
            local vexid = create({description = "untagged plain task"})
            assert.is_nil(rawget(task.tasks[vexid], 'tags'))
            assert.is_nil(rawget(task.tasks[vexid], 'manualtags'))
        end)

        it("adds a hash to manual tags", function()
            local vexid = create({description = "manual tagged task", manualtags = {"pinned", "+#kept", "-urgent"}})
            assert.same({"#pinned", "#kept", "-#urgent"}, task.tasks[vexid].manualtags)
        end)

        it("lets a suppressed tag win over the same tag pinned", function()
            local vexid = create({description = "contradicted tagged task", manualtags = {"-pinned", "kept", "pinned"}})
            assert.same({"#kept"}, task.tasks[vexid].tags)
        end)

        it("rejects a manual tag with a space", function()
            local vexid = task:add({description = "spaced tag task", manualtags = {"two words"}})
            assert.has_error(function() task:resolve(vexid) end)
        end)

        it("names each tag whose rule holds, with a hash", function()
            config.properties.autotags = {
                open = function(t) return t.phase ~= 'final' end,
                ['#costly'] = function(t) return (t.cost or 0) > 5 end,
                ['area/build'] = function(t) return true end,
            }
            local vexid = create({description = "ruled tagged task", cost = 9})
            assert.same({"#area/build", "#costly", "#open"}, task.tasks[vexid].tags)
        end)

        it("sees the resolved task in its rules", function()
            config.properties.autotags = {todo = function(t) return t.status == 'todo' end}
            local vexid = create({vextype = "atom", description = "fresh atom tagged task"})
            assert.same({"#todo"}, task.tasks[vexid].tags)
        end)

        it("follows the rules as the task changes", function()
            config.properties.autotags = {open = function(t) return t.phase ~= 'final' end}
            local vexid = create({description = "following tagged task"})
            setstatus(vexid, "done")
            assert.is_nil(rawget(task.tasks[vexid], 'tags'))
        end)

        it("unions manual tags with the rules' and drops the suppressed ones", function()
            config.properties.autotags = {open = function() return true end, review = function() return true end}
            local vexid = create({description = "overridden tagged task", manualtags = {"pinned", "-review"}})
            assert.same({"#open", "#pinned"}, task.tasks[vexid].tags)
        end)

        it("recomputes tags over a hand edit to them", function()
            config.properties.autotags = {open = function() return true end}
            local vexid = create({description = "hand edited tags task"})
            task:set(vexid, {tags = {"#bogus"}})
            task:resolve(vexid)
            assert.same({"#open"}, task.tasks[vexid].tags)
        end)

        it("throws tag-rule-failed when a rule errors", function()
            config.properties.autotags = {broken = function() error("boom") end}
            local vexid = task:add({description = "broken rule task"})
            assert.is_false(pcall(function() task:resolve(vexid) end))
            assert.stub(cli.throw).was_called_with(cli, 'tag-rule-failed', '#broken', vexid, match._)
        end)

        it("throws bad-autotags when the rules are not tag names mapped to functions", function()
            for _, rules in ipairs({"done", {done = true}, {"done"}, {['two words'] = function() end}}) do
                config.properties.autotags = rules
                local vexid = task:add({description = "badly ruled task " .. _})
                assert.is_false(pcall(function() task:resolve(vexid) end))
                assert.stub(cli.throw).was_called_with(cli, 'bad-autotags', match._)
            end
        end)

    end)

    describe("recurring tasks", function()

        it("adds the next task, its over date moved on by the recurrence, when one is done", function()
            local vexid = create({description = "recurring spec chore", recur = 'weekly', due = 1000000, vexbody = "same body"})
            setstatus(vexid, 'done')
            local next = task.tasks["recurring-spec-chore-2"]
            assert.equal('todo', next.status)
            assert.equal('weekly', next.recur)
            assert.equal('due', next.over)
            assert.equal(1000000 + 7 * 86400, next.due)
            assert.equal("same body", next.vexbody)
            assert.is_true(next.created >= task.tasks[vexid].created)
        end)

        it("recurs from now when the over field is empty", function()
            local vexid = create({description = "undated recurring chore", recur = 'daily'})
            local before = os.time()
            setstatus(vexid, 'done')
            local due = task.tasks["undated-recurring-chore-2"].due
            assert.is_true(due >= before + 86400 and due <= os.time() + 86400)
        end)

        it("adds the next task only when the task moves into a final phase", function()
            local vexid = create({description = "resolved recurring chore", recur = 'weekly'})
            task:set(vexid, {cost = 1})
            task:resolve(vexid)
            assert.is_nil(task.tasks["resolved-recurring-chore-2"])
            setstatus(vexid, 'done')
            assert.truthy(task.tasks["resolved-recurring-chore-2"])
            setstatus(vexid, 'done')
            assert.is_nil(task.tasks["resolved-recurring-chore-3"])
        end)

        it("puts the next task among its parent's children", function()
            local parent = create({description = "recurring chores parent", vextype = 'abstract'})
            local child = create({description = "parented recurring chore", recur = 'daily', parent = parent})
            setstatus(child, 'done')
            assert.same({child, "parented-recurring-chore-2"}, task.tasks[parent].children)
        end)

        it("rejects a recurrence it cannot read or one that never moves on", function()
            for _, recur in ipairs {'sometimes', 'today'} do
                assert.has_error(function() create({description = "badly recurring chore", recur = recur}) end)
            end
        end)

        it("rejects recurring over a field that is not a date", function()
            assert.has_error(function() create({description = "costly recurring chore", recur = 'weekly', over = 'cost'}) end)
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', match._, match._, match._)
        end)

    end)

end)
