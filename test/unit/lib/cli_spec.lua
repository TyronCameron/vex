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

    it("makes the raw string available to verbs via args.raw", function()
        local captured
        cli:verb("_test_raw_capture") {
            function(args) captured = args.raw; return nil end,
            doc = "raw capture test"
        }
        cli:run('_test_raw_capture one two --flag value')
        assert.equal('_test_raw_capture one two --flag value', captured)
    end)

    it("splits plain whitespace-separated words as before", function()
        local captured
        cli:verb("_test_tok_plain") {
            function(args) captured = args:positional(); return nil end,
            doc = "tok test"
        }
        cli:run('_test_tok_plain one two three')
        assert.same({"one", "two", "three"}, captured)
    end)

    it("respects double quotes so a quoted phrase is one flag value", function()
        local captured
        cli:verb("_test_dquote") {
            function(args) captured = args:flags(); return nil end,
            doc = "dquote test"
        }
        cli:run('_test_dquote --flag "a b c"')
        assert.equal("a b c", captured.flag)
    end)

    it("respects single quotes so a quoted phrase is one flag value", function()
        local captured
        cli:verb("_test_squote") {
            function(args) captured = args:flags(); return nil end,
            doc = "squote test"
        }
        cli:run("_test_squote --flag 'a b c'")
        assert.equal("a b c", captured.flag)
    end)

    it("glues a quoted segment onto adjacent unquoted text in the same word", function()
        local captured
        cli:verb("_test_glue") {
            function(args) captured = args:flags(); return nil end,
            doc = "glue test"
        }
        cli:run('_test_glue --filter status:"not done"')
        assert.equal("status:not done", captured.filter)
    end)

    it("handles the classic quote-interaction idiom ('don'\\''t')", function()
        local captured
        cli:verb("_test_interact") {
            function(args) captured = args:flags(); return nil end,
            doc = "interaction test"
        }
        cli:run([[_test_interact --flag 'don'\''t']])
        assert.equal("don't", captured.flag)
    end)

    it("unescapes \\\" and \\\\ inside double quotes", function()
        local captured
        cli:verb("_test_escape") {
            function(args) captured = args:flags(); return nil end,
            doc = "escape test"
        }
        cli:run('_test_escape --flag "say \\"hi\\" now"')
        assert.equal('say "hi" now', captured.flag)
    end)

    it("rawify quotes a word so it round-trips through run() as one word", function()
        local raw = cli:rawify({"add", "Buy", "milk", "--owner", "not done"})
        local captured
        cli:verb("_test_rawify") {
            function(args) captured = args:flags(); return nil end,
            doc = "rawify test"
        }
        cli:run((raw:gsub("^add", "_test_rawify")))
        assert.equal("not done", captured.owner)
    end)

end)
