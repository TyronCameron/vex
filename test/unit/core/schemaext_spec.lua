local cli = require 'lib.cli'
local schema = require 'lib.schema'
require 'core.schemaext'

describe("schemaext", function()

    describe("path", function()
        it("normalises a relative path when prevalidating it", function()
            assert.equal("a/b", schema.path:prevalidate("./a//b/"))
            assert.equal(".", schema.path:prevalidate(""))
            assert.equal(42, schema.path:prevalidate(42))
        end)

        it("accepts a relative path and rejects an absolute one or a non-string", function()
            assert.is_true(schema.path:validate("a/b"))
            assert.is_false(schema.path:validate("/a/b"))
            assert.is_false(schema.path:validate(5))
        end)
    end)

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
