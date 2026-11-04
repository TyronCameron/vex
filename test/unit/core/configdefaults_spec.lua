local defaults = require 'core.configdefaults'

describe("configdefaults", function()

    it("keeps task files flat in the project, with plain tasks, no owners and a hundred log lines", function()
        assert.equal('.', defaults.taskfolder)
        assert.same({tasktype = 'task'}, defaults.default)
        assert.same({groupby = {}}, defaults.paths)
        assert.same({}, defaults.taskowners)
        assert.equal(100, defaults.loglimit)
    end)

    it("leaves modified out of a task's fingerprint", function()
        assert.same({exclude = {'modified'}}, defaults.fingerprint)
    end)

end)
