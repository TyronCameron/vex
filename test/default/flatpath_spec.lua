-- Test file for default/flatpath.lua
local busted = require 'busted'
local flatpath = require 'default.flatpath'

describe("flatpath", function()

    it("returns the vexid with a .md extension", function()
        local result = flatpath.path(nil, nil, "my-task-1")
        assert.equal("my-task-1.md", result)
    end)

    it("works with any vexid string", function()
        assert.equal("hello-world-2.md",   flatpath.path(nil, nil, "hello-world-2"))
        assert.equal("fix-bug-3.md",        flatpath.path(nil, nil, "fix-bug-3"))
    end)

    it("path function ignores the taskmanager and config arguments", function()
        local result1 = flatpath.path(nil,  nil,  "task-1")
        local result2 = flatpath.path({},   {},   "task-1")
        local result3 = flatpath.path("tm", "cfg","task-1")
        assert.equal("task-1.md", result1)
        assert.equal("task-1.md", result2)
        assert.equal("task-1.md", result3)
    end)

end)
