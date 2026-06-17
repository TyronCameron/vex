-- Test file for lib/cli.lua
local busted = require 'busted'
local cli = require 'lib.cli'

describe("CLI", function()

    it("has the correct entrypoint", function()
        assert.equal("vex", cli.entrypoint)
    end)

    it("has a built-in help verb", function()
        assert.truthy(cli.verbs.help)
        assert.is_function(cli.verbs.help[1])
        assert.is_string(cli.verbs.help.doc)
    end)

    it("has built-in usage and bug error types", function()
        assert.truthy(cli.errors.usage)
        assert.truthy(cli.errors.bug)
    end)

    it("registers a verb with `cli:verb`", function()
        cli:verb("_test_noop") {
            function(args) return "noop" end,
            doc = "no-op test verb"
        }
        assert.truthy(cli.verbs["_test_noop"])
        assert.is_function(cli.verbs["_test_noop"][1])
        assert.equal("no-op test verb", cli.verbs["_test_noop"].doc)
    end)

    it("calls a registered verb and returns its result", function()
        cli:verb("_test_return") {
            function(args) return "hello" end,
            doc = "return test"
        }
        local result = cli:call("_test_return", {})
        assert.equal("hello", result)
    end)

    it("passes arguments to the verb function", function()
        cli:verb("_test_args") {
            function(args) return args[1] end,
            doc = "args test"
        }
        local result = cli:call("_test_args", {"world"})
        assert.equal("world", result)
    end)

    it("registers error types with `cli:error`", function()
        cli:error("_test_err") {
            function(msg) return "err: " .. tostring(msg) end
        }
        assert.truthy(cli.errors["_test_err"])
    end)

    it("error handlers produce the correct message", function()
        cli:error("_test_msg") {
            function(path) return "cannot find: " .. tostring(path) end
        }
        local handler = cli.errors["_test_msg"][1]
        assert.equal("cannot find: /some/path", handler("/some/path"))
    end)

end)
