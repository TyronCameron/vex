local frontmatter = require 'default.canonicalfrontmatter'

describe("canonicalfrontmatter", function()

    it("keeps every field except the body", function()
        assert.same({vexid = "a-1", status = "todo"}, frontmatter({vexid = "a-1", status = "todo", vexbody = "notes"}))
    end)

end)
