local busted = require 'busted'
local view = require 'core.view'

local function make_focus(tasks)
    return { get = function() return tasks end }
end

describe("view", function()

    local sample_tasks = {
        {vexid = "hello-world-1", title = "Hello World", status = "todo"},
    }

    it("singleton loads and is truthy", function()
        assert.truthy(view)
    end)

    it("view.views is a table", function()
        assert.is_table(view.views)
    end)

    it("known views csv, tabular, json are registered", function()
        assert.truthy(view.views["csv"])
        assert.truthy(view.views["tabular"])
        assert.truthy(view.views["json"])
    end)

    it("a custom view can be registered and retrieved", function()
        view:view("__specview") {
            display = function(focus, flags) return "specresult" end
        }
        assert.truthy(view.views["__specview"])
    end)

    it("display 'json' returns a string", function()
        local result = view:display("json", make_focus(sample_tasks), {})
        assert.is_string(result)
    end)

    it("display 'json' output contains the task vexid", function()
        local result = view:display("json", make_focus(sample_tasks), {})
        assert.truthy(result:find("hello-world-1", 1, true))
    end)

    it("display of a custom view calls its display function", function()
        view:view("__specview2") {
            display = function(focus, flags) return "custom-output" end
        }
        local result = view:display("__specview2", make_focus({}), {})
        assert.equal("custom-output", result)
    end)

end)
