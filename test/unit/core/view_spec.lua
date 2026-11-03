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

    it("writes dates and lists readably in the csv view, quoting what needs it", function()
        local quoted = create({description = 'viewed "quoted", comma task', due = "2026-08-01 09:00:00"})
        local result = view:display('csv', focus.focus(quoted), {})
        assert.truthy(result:find('"viewed ""quoted"", comma task"', 1, true))
        assert.truthy(result:find('2026-08-01 09:00:00', 1, true))
        assert.truthy(view:display('csv', focus.focus(parent), {}):find('[[' .. child .. ']]', 1, true))
    end)

    it("writes a timed event for a datetime in the ics view, defaulting to due", function()
        local result = view:display('ics', focus.focus(child), {})
        assert.truthy(result:find('UID:' .. child .. '@vex\r\n', 1, true))
        assert.truthy(result:find('SUMMARY:viewed child task\r\n', 1, true))
        assert.truthy(result:find('DTSTART:%d+T%d+Z\r\n'))
        assert.truthy(result:find('RELATED-TO;RELTYPE=PARENT:' .. parent .. '@vex', 1, true))
    end)

    it("writes an all-day event for midnight and skips tasks without the field", function()
        local midnight = create({description = "viewed midnight task", due = "2026-08-01 00:00:00"})
        local result = view:display('ics', focus.focus({midnight, parent}), {})
        assert.truthy(result:find('DTSTART;VALUE=DATE:20260801\r\n', 1, true))
        assert.truthy(result:find('DTEND;VALUE=DATE:20260802\r\n', 1, true))
        assert.is_nil(result:find(parent, 1, true))
    end)

    it("takes the date field from --by", function()
        local result = view:display('ics', focus.focus(parent), {by = 'created'})
        assert.truthy(result:find('UID:' .. parent .. '@vex', 1, true))
    end)

    it("rejects a field that is not a date", function()
        local cli = require 'lib.cli'
        stub(cli, 'throw', function(self, name) error(name) end)
        local ok, err = pcall(view.display, view, 'ics', focus.focus(child), {by = 'description'})
        cli.throw:revert()
        assert.is_false(ok)
        assert.truthy(err:find('not-a-date-field', 1, true))
    end)

    describe("list", function()

        local cli = require 'lib.cli'
        local function list(focusname, flags, flagline)
            return view:display('list', focus.focus(unpack(focusname)), flags or {}, flagline and cli:parse(flagline) or {})
        end

        it("nests each task under the tasks that link to it through children by default", function()
            assert.equal("- " .. parent .. "\n  - " .. child, list({child, parent}))
        end)

        it("leaves a task at the top when nothing in the focus links to it", function()
            assert.equal("- " .. child, list({child}))
        end)

        it("shows the chosen fields joined by the separator", function()
            local result = list({child, parent}, {fields = {'vexid', 'status'}, sep = ' | '})
            assert.equal("- " .. parent .. " | todo\n  - " .. child .. " | todo", result)
        end)

        it("nests along any link field given to indentby", function()
            local result = list({child, dependent}, {indentby = 'dependencies'})
            assert.equal("- " .. dependent .. "\n  - " .. child, result)
        end)

        it("numbers each level of siblings", function()
            local first = create({description = "listed first numbered task", due = "2026-08-02 09:00:00"})
            local second = create({description = "listed second numbered task", due = "2026-08-03 09:00:00"})
            local top = create({description = "listed numbered abstract", vextype = 'abstract', children = {first, second}})
            local result = list({top, first, second}, {bullet = 'numbered', orderby = 'due'})
            assert.equal("1. " .. top .. "\n   1. " .. first .. "\n   2. " .. second, result)
        end)

        it("marks finished tasks in the checkbox bullets", function()
            local result = list({child, dependent}, {bullet = 'check', indentby = 'dependencies'})
            assert.equal("- [x] " .. dependent .. "\n  - [ ] " .. child, result)
        end)

        it("orders the siblings under each parent", function()
            local early = create({description = "listed early ordered task", due = "2026-08-02 09:00:00"})
            local late = create({description = "listed late ordered task", due = "2026-08-09 09:00:00"})
            local top = create({description = "listed ordered abstract", vextype = 'abstract', children = {early, late}})
            assert.equal("- " .. top .. "\n  - " .. early .. "\n  - " .. late, list({late, early, top}, {orderby = 'due'}))
            assert.equal("- " .. top .. "\n  - " .. late .. "\n  - " .. early, list({early, late, top}, {orderby = {'due', 'desc'}}))
        end)

        it("orders by urgency by default", function()
            local soon = create({description = "listed soon urgent task", due = os.time() + 86400})
            local later = create({description = "listed later urgent task", due = os.time() + 9 * 86400})
            assert.equal("- " .. soon .. "\n- " .. later, list({later, soon}))
        end)

        it("folds the levels past the fold, counting what is hidden", function()
            assert.equal("- " .. parent .. " (+1)", list({child, parent}, {fold = '1'}))
        end)

        it("lines the separators up across levels with align", function()
            local result = list({child, parent}, {fields = {'vexid', 'status'}, sep = ' | '}, '--align')
            local first, second = result:match("([^\n]*)\n([^\n]*)")
            assert.equal(first:find(' | ', 1, true), second:find(' | ', 1, true))
            assert.is_nil(list({child, parent}, {fields = {'vexid', 'status'}, sep = ' | '}):match("^[^\n]*\n[^\n]*"):find("  | ", 1, true))
        end)

        it("renders nothing for an empty focus", function()
            assert.equal("", list({'none'}))
        end)

        it("rejects a bullet it does not know", function()
            stub(cli, 'throw', function(self, name) error(name) end)
            local ok, err = pcall(list, {child}, {bullet = 'stars'})
            cli.throw:revert()
            assert.is_false(ok)
            assert.truthy(err:find('usage', 1, true))
        end)

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
