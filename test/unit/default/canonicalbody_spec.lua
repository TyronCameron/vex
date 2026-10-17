local body = require 'default.canonicalbody'

describe("canonicalbody", function()

    it("is the task's vexbody", function()
        assert.equal("notes", body({vexid = "a-1", vexbody = "notes"}))
    end)

end)
