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
        task:set(dependent, {status = 'doing'})
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

    it("renders every view for an empty focus (fix-views-crashing-empty-1)", function()
        assert.same({}, crashes('none'))
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

end)
