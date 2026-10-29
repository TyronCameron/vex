local event = require 'lib.event'
local view = require 'core.view'
local focus = require 'core.focus'
local task = require 'core.task'

local function create(properties)
    local vexid = task:add(properties)
    task:resolve(vexid)
    task:write(vexid)
    return vexid
end

describe("view", function()

    local child, parent, dependent

    setup(function()
        child = create({description = "viewed child task", cost = "5", due = "2026-08-01 09:00:00"})
        parent = create({description = "viewed parent abstract", vextype = 'abstract', children = {child}})
        dependent = create({description = "viewed dependent atom", vextype = 'atom', dependencies = {child}})
        task:set(dependent, {status = 'done'})
        task:resolve(dependent)
        task:write(dependent)
    end)

    local function crashes(focusname, skip)
        local crashed = {}
        for name in pairs(view.views) do
            if name ~= skip then
                local ok, result = pcall(view.display, view, name, focus.focus(focusname), {})
                if not ok or type(result) ~= "string" then crashed[name] = tostring(result) end
            end
        end
        return crashed
    end

    it("renders every view for a mix of task types, links and statuses", function()
        assert.same({}, crashes('all', 'singular'))
    end)

    it("renders every view for an empty focus", function()
        assert.same({}, crashes('none', 'singular'))
    end)

    it("rejects the singular view of an empty focus as a usage error", function()
        local cli = require 'lib.cli'
        stub(cli, 'throw', function(self, name) error(name) end)
        local ok, err = pcall(view.display, view, 'singular', focus.focus('none'), {})
        cli.throw:revert()
        assert.is_false(ok)
        assert.truthy(err:find('usage', 1, true))
    end)

    it("shows only the selected fields in the tabular view", function()
        local result = view:display('tabular', focus.focus('all'):select('status'), {})
        assert.truthy(result:find("status", 1, true))
        assert.is_nil(result:find("description", 1, true))
        assert.is_nil(result:find("created", 1, true))
    end)

    it("shows no subheaders for an ungrouped focus in the tabular view", function()
        local result = view:display('tabular', focus.focus('all'), {})
        assert.is_nil(result:find("vextype: ", 1, true))
    end)

    it("shows a subheader per group of a grouped focus in the tabular view", function()
        local result = view:display('tabular', focus.focus('all'):groupby('vextype'):select('vextype'), {})
        for _, vextype in ipairs({'abstract', 'atom', 'task'}) do
            assert.truthy(result:find("vextype: " .. vextype, 1, true))
        end
        assert.truthy(result:find("vextype: abstract", 1, true) < result:find(parent, 1, true))
        assert.truthy(result:find(parent, 1, true) < result:find("vextype: atom", 1, true))
    end)

    it("nests the subheaders of a focus grouped by several fields in the tabular view", function()
        local result = view:display('tabular', focus.focus('all'):groupby('status', 'vextype'), {})
        local plain = result:gsub("\27%[[0-9;]*m", "")
        assert.truthy(plain:find("│ status: done", 1, true))
        assert.truthy(plain:find("│ │ vextype: atom", 1, true))
        assert.truthy(plain:find("│ │ │ " .. dependent, 1, true))
        assert.equal(1, select(2, plain:gsub("│ status: todo", "")))
    end)

    it("shows a field the first task lacks in the tabular view", function()
        local result = view:display('tabular', focus.focus(child, parent), {})
        assert.truthy(result:find("children", 1, true))
        assert.truthy(result:find(child, 1, true))
    end)

    it("renders the singular view for each linked task", function()
        for _, vexid in ipairs({child, parent, dependent}) do
            local result = view:display('singular', focus.focus(vexid), {})
            assert.truthy(result:find(vexid:upper(), 1, true))
        end
    end)

    it("lists every task in the csv and json views", function()
        for _, name in ipairs({'csv', 'json'}) do
            local result = view:display(name, focus.focus('all'), {})
            for _, vexid in ipairs({child, parent, dependent}) do
                assert.truthy(result:find(vexid, 1, true), name .. " is missing " .. vexid)
            end
        end
    end)

    it("fires pre- and post-view-display with the view, focus and flags, then the result", function()
        local fired = {}
        for _, name in ipairs {'pre-view-display', 'post-view-display'} do
            event:register(name, 'spec', function(...) fired[name] = {...} end)
        end
        local f, flags = focus.focus('all'), {}
        local result = view:display('csv', f, flags)
        for _, name in ipairs {'pre-view-display', 'post-view-display'} do event:remove(name, 'spec') end
        assert.same({'csv', f, flags}, fired['pre-view-display'])
        assert.same({'csv', f, flags, result}, fired['post-view-display'])
    end)

end)
