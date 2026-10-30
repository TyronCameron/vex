local cli = require 'lib.cli'
local init = require 'core.init'

local function tmpdir()
    local handle = io.popen("mktemp -d")
    local dir = handle:read("*l")
    handle:close()
    return dir
end

describe("init", function()

    it("sets up a .vex folder whose config keeps tasks next to it", function()
        local dir = tmpdir()
        init(dir)
        local config = dofile(dir .. "/.vex/config.lua")
        assert.equal('.', config.taskfolder)
        assert.same({}, config.taskowners)
        assert.same({tasktype = 'task'}, config.default)
        assert.equal(1000, config.loglimit)
        assert.same({groupby = {"status", "lineage"}}, config.paths)
        assert.is_nil(config.plugins)
        for _, folder in ipairs({"vexdex", "tasks", "recipes", "focuses", "views", "events", "tmp"}) do
            assert.truthy(io.open(dir .. "/.vex/" .. folder .. "/."), folder .. " was not created")
        end
        os.execute("rm -rf '" .. dir .. "'")
    end)

    it("refuses to set up a folder that already has a .vex", function()
        local dir = tmpdir()
        init(dir)
        stub(cli, 'throw', function(self, name) error(name) end)
        local ok, err = pcall(init, dir)
        cli.throw:revert()
        os.execute("rm -rf '" .. dir .. "'")
        assert.is_false(ok)
        assert.truthy(err:find('already-vexed', 1, true))
    end)

end)
