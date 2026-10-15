local busted = require 'busted'
local grouppath = require 'default.grouppath'
local vexdex = require 'core.vexdex'

describe("grouppath", function()

    after_each(function()
        vexdex:unsafe_remove("__grouped-1")
    end)

    it("is flat without groupby", function()
        vexdex:unsafe_add("__grouped-1", { vexid = "__grouped-1", status = "todo" })
        assert.equal("__grouped-1.md", grouppath.path(nil, {}, "__grouped-1"))
    end)

    it("is flat for a task that is not indexed yet", function()
        assert.equal("__grouped-1.md", grouppath.path(nil, { groupby = {"status"} }, "__grouped-1"))
    end)

    it("groups by field values in order, skipping unset fields", function()
        vexdex:unsafe_add("__grouped-1", { vexid = "__grouped-1", status = "todo", owner = "tyron" })
        assert.equal("todo/tyron/__grouped-1.md", grouppath.path(nil, { groupby = {"status", "missing", "owner"} }, "__grouped-1"))
    end)

end)
