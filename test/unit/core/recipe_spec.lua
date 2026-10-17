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
                return taskmanager:add(properties)
            end
        }
        local f = recipe:add('__specchore', {description = "take out the bins"})
        local tasks = f:get()
        assert.equal(1, #tasks)
        assert.equal('atom', tasks[1].vextype)
        assert.equal('todo', task.tasks[tasks[1].vexid].status)
    end)

    it("resolves and focuses on every task a recipe adds", function()
        recipe:recipe '__specpipeline' {
            add = function(taskmanager, properties)
                local spike = taskmanager:add({description = "spike the " .. properties.description})
                local build = taskmanager:add({description = "build the " .. properties.description})
                return taskmanager:add({description = properties.description, vextype = 'abstract', children = {spike, build}})
            end
        }
        local vexids = {}
        recipe:add('__specpipeline', {description = "release pipeline"}):each(function(vexid)
            table.insert(vexids, vexid)
        end)
        assert.same({"spike-release-pipeline-1", "build-release-pipeline-1", "release-pipeline-1"}, vexids)
        for _, vexid in ipairs(vexids) do
            assert.equal('todo', task.tasks[vexid].status)
        end
    end)

    it("makes an abstract with the abstract recipe", function()
        local tasks = recipe:add('abstract', {description = "plan the release"}):get()
        assert.equal('abstract', tasks[1].vextype)
        assert.same({}, tasks[1].children)
    end)

    it("rejects an unknown recipe", function()
        assert.has_error(function() recipe:add('__nosuchrecipe', {description = "anything at all"}) end)
        assert.stub(cli.throw).was.called_with(cli, 'unknown-recipe', '__nosuchrecipe')
    end)

end)
