-- Test file for lib/cli.lua
local busted = require 'busted'
local cli = require 'lib.cli'
local event = require 'lib.event'

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

    it("fires pre-verb-<name> before a verb and post-verb-<name> after it", function()
        local seen = {}
        cli:verb("_test_events") {
            function(args) table.insert(seen, 'verb'); return "done" end,
            doc = "events test"
        }
        event:register('pre-verb-_test_events', 'spec', function(args) table.insert(seen, {'pre', args[1]}) end)
        event:register('post-verb-_test_events', 'spec', function(args, result) table.insert(seen, {'post', args[1], result}) end)
        cli:call("_test_events", {"arg"})
        event:remove('pre-verb-_test_events', 'spec')
        event:remove('post-verb-_test_events', 'spec')
        assert.same({{'pre', 'arg'}, 'verb', {'post', 'arg', 'done'}}, seen)
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

        it("reports a crashing verb as a bug with its traceback", function()
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

        it("reports a failing hook as hook-failed, naming the hook, without running the verb", function()
            local ran = false
            cli:verb("_test_hooked") {
                function(args) ran = true end,
                doc = "hook test"
            }
            event:register('pre-verb-_test_hooked', 'spec-hook', function() error("owner required") end)
            assert.has_error(function() cli:call("_test_hooked", {}) end)
            event:remove('pre-verb-_test_hooked', 'spec-hook')
            local _, name, hookevent, hook, err = unpack(cli.throw.calls[1].vals)
            assert.equal('hook-failed', name)
            assert.equal('pre-verb-_test_hooked', hookevent)
            assert.equal('spec-hook', hook)
            assert.truthy(tostring(err):find("owner required", 1, true))
            assert.is_false(ran)
        end)

    end)

    it("exits with a message when throwing an unregistered error", function()
        local stderr, written = io.stderr, {}
        io.stderr = {write = function(self, text) table.insert(written, text) end}
        stub(os, 'exit', function() error('exited') end)
        local ok, err = pcall(cli.throw, cli, '_test_unregistered', 'details')
        io.stderr = stderr
        os.exit:revert()
        assert.is_false(ok)
        assert.truthy(err:find('exited', 1, true))
        assert.truthy(table.concat(written):find('_test_unregistered', 1, true))
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

    describe("comma lists", function()

        local function parsed(argv)
            return cli:parse(cli:rawify(argv))
        end

        it("splits a flag value on commas into a list", function()
            assert.same({"a", "b", "c"}, parsed({"--children", "a,b,c"}):flags().children)
        end)

        it("splits a positional word on commas into a list", function()
            assert.same({{"a", "b"}}, parsed({"a,b"}):positional())
        end)

        it("keeps commas inside quotes, so a value with spaces stays one string", function()
            assert.equal("Fixed, then tested", parsed({"--vexbody", "Fixed, then tested"}):flags().vexbody)
            assert.equal("a,b", cli:parse('--flag "a,b"'):flags().flag)
        end)

        it("keeps a comma escaped with a backslash", function()
            assert.equal("a,b", parsed({"--flag", "a\\,b"}):flags().flag)
            assert.equal("a,b", cli:parse('--flag "a\\,b"'):flags().flag)
        end)

        it("tells flags apart from positional lists", function()
            local args = parsed({"a,b", "--select", "x,y", "--due"})
            assert.is_false(cli.isflag(args[1]))
            assert.is_true(cli.isflag(args[2]))
            assert.is_true(cli.isflag(args[3]))
        end)

        it("rejoins positional lists with commas as text", function()
            assert.equal("Buy milk, eggs", parsed({"Buy", "milk,", "eggs"}):text())
        end)

        it("reads positional words as literals, rejoining lists and unescaping", function()
            assert.same({",", "a,b"}, parsed({",", "a,b"}):literals())
            assert.same({"\n", "\t", "\r", "\\"}, parsed({"\\n", "\\t", "\\r", "\\\\"}):literals())
            assert.same({"", "x\\y"}, parsed({"", "x\\y"}):literals())
        end)

        it("maps each flag to the valueless flag just before it", function()
            local args = parsed({"--insert", "--children", "a,b", "--status", "done", "--remove", "--options", "c"})
            assert.same({children = "insert", options = "remove"}, args:modifiers())
        end)

    end)

end)
