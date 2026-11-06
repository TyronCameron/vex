local cli = require 'lib.cli'
local schema = require 'lib.schema'
require 'core.schemaext'

describe("schemaext", function()

    describe("words", function()
        it("needs at least that many words", function()
            assert.is_true(schema.words {2}:validate("two words"))
            assert.is_false(schema.words {2}:validate("one"))
            assert.is_false(schema.words {2}:validate(5))
        end)
    end)

    describe("vextype", function()
        it("accepts only a task type the task manager knows", function()
            local context = {taskmanager = {tasktypes = {task = {}}}}
            assert.is_true(schema.vextype:validate("task", context))
            assert.is_false(schema.vextype:validate("nope", context))
        end)
    end)

    describe("tag", function()
        it("puts a # in front of a word and accepts only a word without spaces", function()
            assert.equal("#urgent", schema.tag:prevalidate("urgent"))
            assert.equal("#urgent", schema.tag:prevalidate("#urgent"))
            assert.is_true(schema.tag:validate("#urgent"))
            assert.is_false(schema.tag:validate("#two words"))
            assert.is_false(schema.tag:validate("urgent"))
        end)
    end)

    describe("tagoverride", function()
        it("is a tag, or a tag with a - in front to suppress it", function()
            assert.equal("-#urgent", schema.tagoverride:prevalidate("-urgent"))
            assert.equal("#urgent", schema.tagoverride:prevalidate("+urgent"))
            assert.is_true(schema.tagoverride:validate("-#urgent"))
            assert.is_false(schema.tagoverride:validate("-#two words"))
        end)
    end)

    describe("status", function()
        local s = schema.atleast {status = schema.status}

        local function transition(instance, previous)
            local context = {previous = previous}
            return s:validate(s:prevalidate(instance, context), context)
        end

        it("starts at todo", function()
            assert.equal("todo", s:prevalidate({}, {}).status)
        end)

        it("lets todo become done", function()
            assert.is_true(transition({status = "done"}, {status = "todo"}))
        end)

        it("does not let done go back, or accept a status it does not have", function()
            assert.is_false(transition({status = "todo"}, {status = "done"}))
            assert.is_false(transition({status = "doing"}, {status = "todo"}))
        end)
    end)

    describe("dependencies", function()
        it("is optional", function()
            assert.is_nil(schema.dependencies:prevalidate(nil, {}))
            assert.is_true(schema.dependencies:validate(nil, {}))
        end)
    end)

    describe("children", function()
        it("defaults to an empty list", function()
            assert.same({}, schema.children:prevalidate(nil, {}))
        end)
    end)

    describe("constraints", function()
        before_each(function()
            stub(cli, 'throw', function(self, name) error(name) end)
        end)

        after_each(function()
            cli.throw:revert()
        end)

        it("refuses a task that is its own child", function()
            assert.has_error(function() schema.notself:validate("a-task-1", {vexid = "a-task-1"}) end)
            assert.stub(cli.throw).was.called_with(cli, 'self-child', "a-task-1")
            assert.is_true(schema.notself:validate("other-task-1", {vexid = "a-task-1"}))
        end)
    end)

end)
