local event = require 'lib.event'
local cli = require 'lib.cli'
local recipe = require 'core.recipe'
local task = require 'core.task'

describe("Recipe", function()

    before_each(function()
        stub(cli, 'throw', function(self, name) error(name) end)
    end)

    after_each(function()
        cli.throw:revert()
    end)

    it("resolves the task a recipe adds and focuses on it", function()
        recipe:recipe '__specchore' {
            add = function(taskmanager, properties)
                properties.vextype = 'atom'
                return {taskmanager:add(properties)}
            end
        }
        local f = recipe:add('__specchore', {description = "take out the bins"})
        local tasks = f:get()
        assert.equal(1, #tasks)
        assert.equal('atom', tasks[1].vextype)
        assert.equal('todo', task.tasks[tasks[1].vexid].status)
    end)

    it("resolves and focuses on every vexid the recipe returns, in that order", function()
        recipe:recipe '__specpipeline' {
            add = function(taskmanager, properties)
                local spike = taskmanager:add({description = "spike the " .. properties.description})
                local build = taskmanager:add({description = "build the " .. properties.description})
                local parent = taskmanager:add({description = properties.description, vextype = 'abstract', children = {spike, build}})
                return {parent, spike, build}
            end
        }
        local vexids = {}
        recipe:add('__specpipeline', {description = "release pipeline"}):each(function(vexid)
            table.insert(vexids, vexid)
        end)
        assert.same({"release-pipeline-1", "spike-release-pipeline-1", "build-release-pipeline-1"}, vexids)
        for _, vexid in ipairs(vexids) do
            assert.equal('todo', task.tasks[vexid].status)
        end
    end)

    it("makes an abstract with the abstract recipe", function()
        local tasks = recipe:add('abstract', {description = "plan the release"}):get()
        assert.equal('abstract', tasks[1].vextype)
        assert.same({}, tasks[1].children)
    end)

    describe("built in", function()

        local recipes = recipe.recipes
        local vexations

        before_each(function()
            vexations = {recurring = recipes.recurring, ['repeat'] = recipes['repeat']}
            package.loaded['core.recipe'] = nil
            local core = require 'core.recipe'
            package.loaded['core.recipe'] = recipe
            recipes.recurring, recipes['repeat'] = core.recipes.recurring, core.recipes['repeat']
        end)

        after_each(function()
            recipes.recurring, recipes['repeat'] = vexations.recurring, vexations['repeat']
        end)

        it("adds a task that recurs over its due date, starting where --start says", function()
            local tasks = recipe:add('recurring', {description = "wash the car", start = 'today', recur = 'weekly'}):get()
            assert.equal(1, #tasks)
            assert.equal('weekly', tasks[1].recur)
            assert.equal('due', tasks[1].over)
            assert.is_nil(tasks[1].start)
            local t = os.date('*t')
            assert.equal(os.time({year = t.year, month = t.month, day = t.day, hour = 0, isdst = false}), tasks[1].due)
        end)

        it("starts the field named in --over", function()
            local tasks = recipe:add('recurring', {description = "renew the licence", start = '2030-01-01', recur = 'yearly', over = 'due'}):get()
            assert.equal(os.time({year = 2030, month = 1, day = 1, hour = 0, isdst = false}), tasks[1].due)
        end)

        it("refuses a recurring task without a recurrence", function()
            assert.has_error(function() recipe:add('recurring', {description = "never recurring task"}) end)
            assert.stub(cli.throw).was.called_with(cli, 'recipe-needs-flag', 'recurring', 'recur', match._)
        end)

        it("adds a task n times", function()
            local tasks = recipe:add('repeat', {description = "fold the laundry", n = '3', cost = 1}):get()
            assert.equal(3, #tasks)
            for _, t in ipairs(tasks) do
                assert.equal("fold the laundry", t.description)
                assert.equal(1, t.cost)
                assert.is_nil(t.n)
            end
        end)

        it("refuses a count that is not a whole number above 0", function()
            for _, n in ipairs {'0', '-1', '1.5', 'lots'} do
                assert.has_error(function() recipe:add('repeat', {description = "badly counted task", n = n}) end)
            end
            assert.has_error(function() recipe:add('repeat', {description = "uncounted task"}) end)
            assert.stub(cli.throw).was.called_with(cli, 'recipe-needs-flag', 'repeat', 'n', match._)
        end)

    end)

    it("rejects an unknown recipe", function()
        assert.has_error(function() recipe:add('__nosuchrecipe', {description = "anything at all"}) end)
        assert.stub(cli.throw).was.called_with(cli, 'unknown-recipe', '__nosuchrecipe')
    end)

    it("fires pre- and post-recipe-add with the recipe and properties, then the focus made", function()
        recipe:recipe '__specevented' {
            add = function(taskmanager, properties) return {taskmanager:add(properties)} end
        }
        local fired = {}
        for _, name in ipairs {'pre-recipe-add', 'post-recipe-add'} do
            event:register(name, 'spec', function(...) fired[name] = {...} end)
        end
        local properties = {description = "evented recipe task"}
        local f = recipe:add('__specevented', properties)
        for _, name in ipairs {'pre-recipe-add', 'post-recipe-add'} do event:remove(name, 'spec') end
        assert.same({'__specevented', properties}, fired['pre-recipe-add'])
        assert.same({'__specevented', f}, fired['post-recipe-add'])
    end)

end)
