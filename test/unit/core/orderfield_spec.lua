-- Test file for core/orderfield.lua
local busted = require 'busted'
local schema = require 'lib.schema'
local task = require 'core.task'
require 'core.orderfield'

describe("schema.order", function()

    it("registers as a schema type", function()
        assert.truthy(schema.order._name == "order", 'order not registered')
    end)

    it("coerces a numeric string on prevalidate", function()
        local s = schema.order {}
        assert.equal(15, s:prevalidate("15"))
    end)

    it("leaves a non-numeric string alone on prevalidate", function()
        local s = schema.order {}
        assert.equal("hello", s:prevalidate("hello"))
    end)

    it("validates an integer", function()
        local s = schema.order {}
        assert.truthy(s:validate(5))
    end)

    it("invalidates a non-integer", function()
        local s = schema.order {}
        assert.falsy(s:validate(5.5))
        assert.falsy(s:validate("hello"))
    end)

end)

describe("schema.order cascading behaviour (via the live task manager)", function()

    task:registertask("__spec_order_task", nil, {
        schema = schema.atleast {
            vexid = schema.str,
            description = schema.str,
            notie = schema.maybe { schema.order { ties = false, gaps = true } },
            tiesok = schema.maybe { schema.order { ties = true } },
            nogap = schema.maybe { schema.order { ties = false, gaps = false } },
            grouped = schema.maybe { schema.order { ties = false, gaps = true, partition = 'group' } },
            group = schema.maybe { schema.str },
        }
    })

    local function makevex(description, fields)
        local props = fields or {}
        props.description = description
        props.vextype = "__spec_order_task"
        local vexid = task:add(props)
        task:resolve(vexid)
        task:write(vexid)
        return vexid
    end

    local created = {}

    local function track(vexid)
        table.insert(created, vexid)
        return vexid
    end

    after_each(function()
        for _, vexid in ipairs(created) do
            task:delete(vexid)
            task:remove(vexid)
        end
        created = {}
    end)

    it("disallows ties: bumps a single colliding sibling by one", function()
        local a = track(makevex("orderfield tie a", { notie = 1 }))
        local b = track(makevex("orderfield tie b", { notie = 1 }))

        -- b is the one just set to 1, so it keeps 1; a (which already held
        -- 1) is the one that gets bumped
        assert.equal(2, task.tasks[a].notie)
        assert.equal(1, task.tasks[b].notie)
    end)

    it("disallows ties: cascades a chain of collisions while leaving unrelated tasks alone", function()
        local a = track(makevex("orderfield chain a", { notie = 1 }))
        local b = track(makevex("orderfield chain b", { notie = 2 }))
        local c = track(makevex("orderfield chain c", { notie = 3 }))
        local unrelated = track(makevex("orderfield chain unrelated", { notie = 10 }))

        -- setting a fresh task to 1 should push a->2 (colliding with b),
        -- b->3 (colliding with c), c->4
        local d = track(makevex("orderfield chain d", { notie = 1 }))

        assert.equal(1, task.tasks[d].notie)
        assert.equal(2, task.tasks[a].notie)
        assert.equal(3, task.tasks[b].notie)
        assert.equal(4, task.tasks[c].notie)
        assert.equal(10, task.tasks[unrelated].notie)
    end)

    it("allows ties when configured to", function()
        local a = track(makevex("orderfield allowtie a", { tiesok = 5 }))
        local b = track(makevex("orderfield allowtie b", { tiesok = 5 }))

        assert.equal(5, task.tasks[a].tiesok)
        assert.equal(5, task.tasks[b].tiesok)
    end)

    it("disallows gaps: compacts the partition into a contiguous range", function()
        local a = track(makevex("orderfield nogap a", { nogap = 5 }))
        local b = track(makevex("orderfield nogap b", { nogap = 9 }))

        -- a=5, b=9 -> compacted to 1, 2 (relative order preserved)
        assert.equal(1, task.tasks[a].nogap)
        assert.equal(2, task.tasks[b].nogap)

        local c = track(makevex("orderfield nogap c", { nogap = 100 }))
        -- a=1, b=2, c=100 -> compacted to 1, 2, 3
        assert.equal(1, task.tasks[a].nogap)
        assert.equal(2, task.tasks[b].nogap)
        assert.equal(3, task.tasks[c].nogap)
    end)

    it("scopes ties to the configured partition", function()
        local a = track(makevex("orderfield partition a", { grouped = 1, group = "x" }))
        local b = track(makevex("orderfield partition b", { grouped = 1, group = "y" }))

        -- different partitions: no bump
        assert.equal(1, task.tasks[a].grouped)
        assert.equal(1, task.tasks[b].grouped)

        local c = track(makevex("orderfield partition c", { grouped = 1, group = "x" }))
        -- same partition as a: bumps a
        assert.equal(1, task.tasks[c].grouped)
        assert.equal(2, task.tasks[a].grouped)
        assert.equal(1, task.tasks[b].grouped)
    end)

end)
