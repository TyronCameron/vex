local flatpath = require 'default.flatpath'

describe("flatpath", function()

    it("puts each task in a markdown file named after its vexid", function()
        assert.equal("my-task-1.md", flatpath.path({}, {}, "my-task-1"))
    end)

end)
