-- Test file for lib/cli.lua
local busted = require 'busted'
local cli = require 'lib.cli'

describe("CLI", function()

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

    it("lists every verb in help", function()
        local help = cli:call("help", {})
        for name in pairs(cli.verbs) do
            assert.truthy(help:find("  " .. name .. " ", 1, true), name .. " is missing from help")
        end
    end)

    describe("failures", function()

        before_each(function()
            stub(cli, 'throw', function(self, name) error(name) end)
        end)

        after_each(function()
            cli.throw:revert()
        end)

        it("rejects an unknown verb as a usage error", function()
            assert.has_error(function() cli:run('_test_no_such_verb') end)
            assert.stub(cli.throw).was.called_with(cli, 'usage', match._)
        end)

        it("reports a crashing verb as a bug with its traceback (show-traceback-internal-errors-1)", function()
            cli:verb("_test_crash") {
                function(args) error("boom") end,
                doc = "crash test"
            }
            assert.has_error(function() cli:call("_test_crash", {}) end)
            local _, name, message, trace = unpack(cli.throw.calls[1].vals)
            assert.equal('bug', name)
            assert.truthy(tostring(message):find("boom", 1, true))
            assert.truthy(trace:find("traceback", 1, true))
        end)

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
