local cli = require 'lib.cli'
local vexdex = require 'core.vexdex'
local task = require 'core.task'
local view = require 'core.view'

local written = {}

local function extension(path, code)
    local f = assert(io.open(vexdex:vexpath(path), "w"))
    f:write(code)
    f:close()
    table.insert(written, vexdex:vexpath(path))
end

local function reload()
    package.loaded['core.extensions'] = nil
    require 'core.extensions'
end

describe("extensions", function()

    after_each(function()
        for _, path in ipairs(written) do os.remove(path) end
        written = {}
    end)

    it("runs every file in .vex/tasks, recipes, focuses and views with vex in scope", function()
        extension("tasks/spectype.lua", "task:task '__spectype':extends 'task' { schema = schema.atleast {} }")
        extension("recipes/specrecipe.lua", "recipe:recipe '__specrecipe' { add = function(t, p) return t:add(p) end }")
        extension("focuses/specfocus.lua", "focus.register_focus('__specfocus', function() return {} end)")
        extension("views/specview.lua", "view:view '__specview' { display = function() return 'shown' end }")
        reload()
        assert.truthy(task.tasktypes.__spectype)
        assert.truthy(require('core.recipe').recipes.__specrecipe)
        assert.truthy(require('core.focus').named.__specfocus)
        assert.equal('shown', view:display('__specview', nil, {}))
    end)

    it("runs every file in .vex/events with event in scope", function()
        extension("events/specevent.lua", "event:on '__specevent' (function(t) t.heard = true end)")
        reload()
        local heard = {}
        require('lib.event'):trigger('__specevent', heard)
        assert.is_true(heard.heard)
    end)

    it("runs task types before the recipes that use them", function()
        extension("tasks/ordered.lua", "task:task '__ordered':extends 'task' { schema = schema.atleast {} }")
        extension("recipes/ordered.lua", "assert(task.tasktypes.__ordered)")
        assert.has_no.errors(reload)
    end)

    it("reports a file that fails to load", function()
        extension("views/broken.lua", "this is not lua")
        stub(cli, 'throw', function(self, name) error(name) end)
        local ok, err = pcall(reload)
        cli.throw:revert()
        assert.is_false(ok)
        assert.truthy(err:find('bad-extension', 1, true))
    end)

end)
