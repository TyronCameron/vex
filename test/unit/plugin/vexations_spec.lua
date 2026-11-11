local cli = require 'lib.cli'
local func = require 'lib.func'
local task = require 'core.task'
require 'core.taskdefinitions'
require 'plugin.vexations'
local recipe = require 'core.recipe'

describe("vexations", function()

    before_each(function()
        stub(cli, 'throw', function(self, name) error(name) end)
    end)

    after_each(function()
        cli.throw:revert()
    end)

    local function create(properties)
        local vexid = task:add(properties)
        task:resolve(vexid)
        task:writeall()
        return vexid
    end

    local function setstatus(vexid, status)
        task:set(vexid, {status = status})
        task:resolve(vexid)
        task:writeall()
    end

    describe("links", function()

        it("rejects a dependency on a task with children", function()
            local parent = create({description = "depended on abstract", vextype = 'abstract'})
            create({description = "grouped leaf task", parent = parent})
            local dependent = task:add({description = "depending on abstract task", dependencies = {parent}})
            assert.has_error(function() task:resolve(dependent) end)
            assert.stub(cli.throw).was.called_with(cli, 'dependency-with-children', dependent, parent)
        end)

        it("rejects a dependency on a decision with options", function()
            local decision = create({description = "depended on decision", vextype = 'decision'})
            create({description = "optional leaf task", parent = decision})
            local dependent = task:add({description = "depending on decision task", dependencies = {decision}})
            assert.has_error(function() task:resolve(dependent) end)
            assert.stub(cli.throw).was.called_with(cli, 'dependency-with-children', dependent, decision)
        end)

        it("places an abstract's phase from the phases of its children", function()
            local parent = create({description = "derived phase abstract", vextype = 'abstract'})
            local first = create({description = "derived phase first", parent = parent})
            local second = create({description = "derived phase second", parent = parent})
            assert.equal("initial", task.tasks[parent].phase)
            setstatus(first, "done")
            assert.equal("interim", task.tasks[parent].phase)
            setstatus(second, "done")
            assert.equal("final", task.tasks[parent].phase)
        end)

        it("lets a decision decide on one of its children", function()
            local decision = create({description = "deciding decision task", vextype = 'decision'})
            local option = create({description = "chosen option task", parent = decision})
            task:set(decision, {decision = option})
            task:resolve(decision)
            assert.equal(option, task.tasks[decision].decision)
        end)

        it("rejects a decision on a task that is not one of its children", function()
            local decision = create({description = "misdeciding decision task", vextype = 'decision'})
            local stranger = create({description = "stranger option task"})
            task:set(decision, {decision = stranger})
            assert.has_error(function() task:resolve(decision) end)
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', decision, match._, match._)
        end)

    end)

    describe("link sets per task type", function()

        local function rejected(properties)
            local vexid = task:add(properties)
            assert.has_error(function() task:resolve(vexid) end)
            assert.stub(cli.throw).was.called_with(cli, 'resolution-failed-validation', vexid, match._, match._)
        end

        local function childless(vextype)
            local parent = create({description = "childless " .. vextype .. " parent", vextype = vextype})
            local child = task:add({description = "unwanted " .. vextype .. " child", parent = parent})
            assert.has_error(function() task:resolve(child) end)
            assert.stub(cli.throw).was.called_with(cli, 'has-children', parent, vextype, child)
        end

        it("lets an atom depend on an atom", function()
            local first = create({description = "atom dependency first", vextype = 'atom'})
            local second = create({description = "atom dependency second", vextype = 'atom', dependencies = {first}})
            assert.same({first}, task.tasks[second].dependencies)
        end)

        it("gives abstracts and decisions children but no dependencies", function()
            local other = create({description = "abstract link target"})
            rejected({description = "abstract with dependencies", vextype = 'abstract', dependencies = {other}})
            rejected({description = "decision with dependencies", vextype = 'decision', dependencies = {other}})
        end)

        it("gives atoms and explorations no children", function()
            childless('atom')
            childless('exploration')
        end)

        it("refuses to turn a task with children into an atom", function()
            local parent = create({description = "switching parent abstract", vextype = 'abstract'})
            local child = create({description = "switching parent child", parent = parent})
            task:set(parent, {vextype = 'atom'})
            assert.has_error(function() task:resolve(parent) end)
            assert.stub(cli.throw).was.called_with(cli, 'has-children', parent, 'atom', child)
        end)

        it("lets any task type sit under an abstract", function()
            local parent = create({description = "welcoming parent abstract", vextype = 'abstract'})
            for _, vextype in ipairs({'task', 'abstract', 'decision', 'exploration', 'atom'}) do
                local child = create({description = "welcomed " .. vextype .. " child", vextype = vextype, parent = parent})
                assert.equal(parent, task.tasks[child].parent)
            end
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
            local parent = create({description = "unstored status abstract", vextype = 'abstract'})
            local child = create({description = "unstored status child", parent = parent})
            setstatus(child, "done")
            assert.is_nil(rawget(task.tasks[parent], 'status'))
            assert.equal("done", task.tasks[parent].status)
        end)

        it("is todo, doing or done according to the children", function()
            local parent = create({description = "derived status abstract", vextype = 'abstract'})
            local first = create({description = "derived status first", parent = parent})
            local second = create({description = "derived status second", parent = parent})
            assert.equal("todo", task.tasks[parent].status)
            setstatus(first, "done")
            assert.equal("doing", task.tasks[parent].status)
            setstatus(second, "done")
            assert.equal("done", task.tasks[parent].status)
        end)

        it("follows a child's status up through nested abstracts", function()
            local outer = create({description = "nested status outer", vextype = 'abstract'})
            local inner = create({description = "nested status inner", vextype = 'abstract', parent = outer})
            local leaf = create({description = "nested status leaf", parent = inner})
            local other = create({description = "nested status other", parent = outer})
            setstatus(leaf, "done")
            assert.equal("doing", task.tasks[outer].status)
            setstatus(other, "done")
            assert.equal("done", task.tasks[outer].status)
        end)

        it("moves back when a finished child is taken away", function()
            local parent = create({description = "taken away abstract", vextype = 'abstract'})
            local first = create({description = "taken away first", parent = parent})
            create({description = "taken away second", parent = parent})
            setstatus(first, "done")
            task:set(first, {}, {parent = "clear"})
            task:resolve(first)
            assert.equal("todo", task.tasks[parent].status)
        end)

    end)

    describe("recipes", function()

        it("puts a recurring task inside an abstract it adds first", function()
            local tasks = recipe:add('recurring', {description = "sweep the yard", recur = 'weekly', start = 'today'}):get()
            assert.equal("sweep-yard-1", tasks[1].vexid)
            assert.equal('abstract', tasks[1].vextype)
            assert.same({"sweep-yard-2"}, tasks[1].children)
            assert.is_nil(rawget(tasks[1], 'recur'))
            assert.equal('weekly', tasks[2].recur)
        end)

        it("puts each next recurring task inside the same abstract", function()
            recipe:add('recurring', {description = "mow the lawn", recur = 'weekly'})
            task:writeall()
            setstatus("mow-lawn-2", "done")
            assert.same({"mow-lawn-2", "mow-lawn-3"}, task.tasks["mow-lawn-1"].children)
        end)

        it("puts repeated tasks inside an abstract it adds first", function()
            local tasks = recipe:add('repeat', {description = "stretch the hamstrings", n = 2}):get()
            assert.same({"stretch-hamstrings-1", "stretch-hamstrings-2", "stretch-hamstrings-3"}, func.imap(tasks, function(t) return t.vexid end))
            assert.same({"stretch-hamstrings-2", "stretch-hamstrings-3"}, tasks[1].children)
        end)

    end)

end)
