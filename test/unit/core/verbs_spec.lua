local cli = require 'lib.cli'
local vexdex = require 'core.vexdex'
local task = require 'core.task'
require 'core.verbs'

local function run(command)
    local printed = {}
    local quiet = stub(_G, 'print', function(text) table.insert(printed, tostring(text)) end)
    cli:run(command)
    quiet:revert()
    return (table.concat(printed, "\n"):gsub("\27%[[%d;]*m", ""):gsub("%s+$", ""))
end

local function file(vexid)
    local f = io.open(task:getabspath(vexid))
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

describe("verbs", function()

    it("add writes a resolved task, prints its vexid and focuses on it", function()
        local vexid = run("add Buy fresh milk --cost 3")
        assert.equal("buy-fresh-milk-1", vexid)
        assert.truthy(file(vexid):find("\ncost: 3\n", 1, true))
        assert.truthy(file(vexid):find("\nstatus: todo\n", 1, true))
        assert.equal(vexid, run("get"))
    end)

    it("set changes a field on disk and leaves the rest", function()
        local vexid = run("add Water the plants --cost 1")
        run("set " .. vexid .. " --benefit 4")
        assert.truthy(file(vexid):find("\nbenefit: 4\n", 1, true))
        assert.truthy(file(vexid):find("\ncost: 1\n", 1, true))
    end)

    it("get prints the selected fields of each focused task", function()
        local vexid = run("add Feed the cat --cost 2")
        local out = run("get " .. vexid .. " --cost --status")
        assert.truthy(out:find("2", 1, true))
        assert.truthy(out:find("todo", 1, true))
    end)

    describe("get separators", function()
        local first, second

        before_each(function()
            first = run("add Separated first task --cost 1")
            second = run("add Separated second task --cost 2")
            run("focus " .. first .. "," .. second)
        end)

        it("joins rows with a newline and columns with a tab by default", function()
            assert.equal(first .. "\t1\n" .. second .. "\t2", run("get --vexid --cost"))
        end)

        it("takes the row separator, then the column separator, after the focus", function()
            assert.equal(first .. "," .. second, run("get prev ,"))
            assert.equal(first .. "|1;" .. second .. "|2", run("get prev ; | --vexid --cost"))
        end)

        it("reads the escapes \\n and \\t in a separator", function()
            assert.equal(first .. "\n" .. second, run("get prev '\\n'"))
            assert.equal(first .. "\t1\n" .. second .. "\t2", run("get prev '\\n' '\\t' --vexid --cost"))
        end)

        it("joins with nothing when a separator is emptied", function()
            assert.equal(first .. second, run("get prev ''"))
            assert.equal(first .. "1\n" .. second .. "2", run("get prev '\\n' '' --vexid --cost"))
        end)

        it("prints no trailing tab", function()
            assert.equal(first .. "," .. second, (run("get prev ,"):gsub("[^%S]+$", "")))
            assert.is_nil(run("get prev ,"):find("\t", 1, true))
        end)
    end)

    it("show prints the task file", function()
        local vexid = run("add Show this task")
        assert.truthy(run("show " .. vexid):find("Show this task", 1, true))
    end)

    it("focus saves a focus and lists its operations when given nothing", function()
        run("add Focus on this task")
        assert.truthy(run("focus all --filter status:todo"):find("Focusing on", 1, true))
        local current = run("focus")
        assert.truthy(current:find("filter", 1, true))
        assert.truthy(current:find("all", 1, true))
    end)

    it("resolve all rebuilds the index from the task files", function()
        local vexid = run("add Reindexed task here")
        vexdex:unsafe_remove(vexid)
        run("resolve all")
        assert.truthy(vexdex:get(vexid))
    end)

    it("resolve all resolves each task once (make-resolve-linear-1)", function()
        local event = require 'lib.event'
        local vexid = run("add Resolved just once")
        local count = 0
        event:register('pre-task-resolve', 'verbs-spec', function(resolved) if resolved == vexid then count = count + 1 end end)
        run("resolve all")
        event:remove('pre-task-resolve', 'verbs-spec')
        assert.equal(1, count)
    end)

    it("remove deletes the task file and its index entry", function()
        local vexid = run("add Throw this away")
        run("remove " .. vexid)
        assert.is_nil(file(vexid))
        assert.is_nil(vexdex:get(vexid))
    end)

    it("recipe adds a task through the named recipe and lists recipes when given none", function()
        local vexid = run("recipe abstract Plan the release")
        assert.truthy(file(vexid):find("\nvextype: abstract\n", 1, true))
        assert.truthy(run("recipe"):find("abstract", 1, true))
    end)

    it("view renders a view of a focus and lists views when given none", function()
        local vexid = run("add Viewed task here")
        assert.truthy(run("view " .. vexid .. " csv"):find(vexid, 1, true))
        assert.truthy(run("view"):find("kanban", 1, true))
    end)

end)
