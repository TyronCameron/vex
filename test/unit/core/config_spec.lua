local config = require 'core.config'

describe("config", function()

    it("reads the project's .vex/config.lua over the defaults", function()
        assert.equal('.', config.taskfolder)
        assert.same({}, config.taskowners)
        assert.equal(100, config.loglimit)
        assert.same({'modified'}, config.fingerprint.exclude)
    end)

end)
