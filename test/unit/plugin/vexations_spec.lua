local cli = require 'lib.cli'
local task = require 'core.task'
require 'core.taskdefinitions'
require 'plugin.vexations'

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

        it("rejects a task in two abstracts' children", function()
            local child = create({description = "shared child task"})
            create({description = "first parent abstract", vextype = 'abstract', children = {child}})
            local second = task:add({description = "second parent abstract", vextype = 'abstract', children = {child}})
            assert.has_error(function() task:resolve(second) end)
            assert.stub(cli.throw).was.called_with(cli, 'multiple-parents', child, second, match._)
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

        it("places an abstract's phase from the phases of its children", function()
            local first = create({description = "derived phase first"})
            local second = create({description = "derived phase second"})
            local parent = create({description = "derived phase abstract", vextype = 'abstract', children = {first, second}})
            assert.equal("initial", task.tasks[parent].phase)
            setstatus(first, "done")
            assert.equal("interim", task.tasks[parent].phase)
            setstatus(second, "done")
            assert.equal("final", task.tasks[parent].phase)
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
            setstatus(child, "done")
            assert.is_nil(rawget(task.tasks[parent], 'status'))
            assert.equal("done", task.tasks[parent].status)
        end)

        it("is stored as todo, doing or done according to the children", function()
            local first = create({description = "derived status first"})
            local second = create({description = "derived status second"})
            local parent = create({description = "derived status abstract", vextype = 'abstract', children = {first, second}})
            assert.equal("todo", task.tasks[parent].status)
            setstatus(first, "done")
            assert.equal("doing", task.tasks[parent].status)
            setstatus(second, "done")
            assert.equal("done", task.tasks[parent].status)
        end)

        it("follows a child's status up through nested abstracts", function()
            local leaf = create({description = "nested status leaf"})
            local other = create({description = "nested status other"})
            local inner = create({description = "nested status inner", vextype = 'abstract', children = {leaf}})
            local outer = create({description = "nested status outer", vextype = 'abstract', children = {inner, other}})
            setstatus(leaf, "done")
            assert.equal("doing", task.tasks[outer].status)
            setstatus(other, "done")
            assert.equal("done", task.tasks[outer].status)
        end)

        it("moves back when a finished child is taken away", function()
            local first = create({description = "taken away first"})
            local second = create({description = "taken away second"})
            local parent = create({description = "taken away abstract", vextype = 'abstract', children = {first, second}})
            setstatus(first, "done")
            task:set(parent, {children = {second}})
            task:resolve(parent)
            assert.equal("todo", task.tasks[parent].status)
        end)

    end)

end)
