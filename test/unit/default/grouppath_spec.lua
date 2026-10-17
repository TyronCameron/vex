local grouppath = require 'default.grouppath'
local vexdex = require 'core.vexdex'

describe("grouppath", function()

    local function indexed(task)
        task.vexid = "__grouped-1"
        vexdex:unsafe_add(task.vexid, task)
        return task.vexid
    end

    after_each(function()
        vexdex:unsafe_remove("__grouped-1")
    end)

    it("puts a task at its vexid without groupby", function()
        assert.equal("__grouped-1.md", grouppath.path({}, {}, indexed {status = "todo"}))
    end)

    it("puts a task at its vexid when paths has no groupby", function()
        assert.equal("__grouped-1.md", grouppath.path({}, {paths = {}}, indexed {status = "todo"}))
    end)

    it("puts a task that isn't indexed yet at its vexid", function()
        assert.equal("__grouped-1.md", grouppath.path({}, {paths = {groupby = {"status"}}}, "__grouped-1"))
    end)

    it("nests a folder for each grouped field, in order, skipping unset fields", function()
        local vexid = indexed {status = "todo", owner = "tyron"}
        assert.equal("todo/tyron/__grouped-1.md", grouppath.path({}, {paths = {groupby = {"status", "missing", "owner"}}}, vexid))
    end)

    it("nests a folder for each element of a list, skipping empty lists", function()
        local vexid = indexed {lineage = {"top", "middle"}, tags = {}}
        assert.equal("top/middle/__grouped-1.md", grouppath.path({}, {paths = {groupby = {"tags", "lineage"}}}, vexid))
    end)

    it("keeps every value to a single folder inside the taskfolder", function()
        local vexid = indexed {owner = "a/b\\c", status = ".."}
        assert.equal("a-b-c/--/__grouped-1.md", grouppath.path({}, {paths = {groupby = {"owner", "status"}}}, vexid))
    end)

end)
