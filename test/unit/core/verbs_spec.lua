local busted = require 'busted'
local cli = require 'lib.cli'
-- core.verbs is loaded by test/load.lua; require here is idempotent
require 'core.verbs'

describe("verbs", function()

    it("cli singleton is truthy after verbs load", function()
        assert.truthy(cli)
    end)

    it("verb 'add' is registered", function()
        assert.is_table(cli.verbs["add"])
    end)

    it("verb 'get' is registered", function()
        assert.is_table(cli.verbs["get"])
    end)

    it("verb 'set' is registered", function()
        assert.is_table(cli.verbs["set"])
    end)

    it("verb 'remove' is registered", function()
        assert.is_table(cli.verbs["remove"])
    end)

    it("verb 'view' is registered", function()
        assert.is_table(cli.verbs["view"])
    end)

    it("verb 'focus' is registered", function()
        assert.is_table(cli.verbs["focus"])
    end)

end)
