local config = require 'core.config'

describe("config", function()

    it("reads the project's .vex/config.lua", function()
        assert.equal('.', config.taskfolder)
        assert.same({}, config.taskowners)
    end)

end)
