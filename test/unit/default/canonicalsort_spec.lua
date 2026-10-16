local sort = require 'default.canonicalsort'

describe("canonicalsort", function()

    it("puts vexid, vextype and description first, then the rest alphabetically", function()
        local keys = {}
        for key in sort({status = 1, cost = 2, description = 3, vexid = 4, vextype = 5}) do
            table.insert(keys, key)
        end
        assert.same({"vexid", "vextype", "description", "cost", "status"}, keys)
    end)

end)
