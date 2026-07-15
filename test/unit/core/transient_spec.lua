-- Test file for the transient (computed, never-persisted) field system in core/task.lua
local busted = require 'busted'
local schema = require 'lib.schema'
local task = require 'core.task'

describe("transient fields", function()

    task:registertask("__spec_transient_a", nil, {
        schema = schema.atleast {
            vexid = schema.str,
            description = schema.str,
            linkto = schema.maybe { schema.str },
        }
    })

    task:registertask("__spec_transient_b", nil, {
        schema = schema.atleast {
            vexid = schema.str,
            description = schema.str,
        }
    })

    task:transient '__spec_scoped' {
        tasktypes = {'__spec_transient_a'},
        derive = function(t, context) return 'scoped:' .. t.vexid end
    }

    task:transient '__spec_global' {
        derive = function(t, context) return 'global:' .. t.vexid end
    }

    task:transient '__spec_crosslink' {
        tasktypes = {'__spec_transient_a'},
        derive = function(t, context)
            if not t.linkto then return nil end
            local other = context.taskmanager:getsingle(t.linkto)
            return other and other.description
        end
    }

    local created = {}

    local function track(vexid)
        table.insert(created, vexid)
        return vexid
    end

    local function makevex(vextype, description, fields)
        local props = fields or {}
        props.description = description
        props.vextype = vextype
        local vexid = task:add(props)
        task:resolve(vexid)
        task:write(vexid)
        return track(vexid)
    end

    after_each(function()
        for _, vexid in ipairs(created) do
            task:delete(vexid)
            task:remove(vexid)
        end
        created = {}
    end)

    it("applies a scoped transient only to its declared task type", function()
        local a = makevex("__spec_transient_a", "transient scoped a")
        local b = makevex("__spec_transient_b", "transient scoped b")

        assert.equal("scoped:" .. a, task:present(a).__spec_scoped)
        assert.is_nil(task:present(b).__spec_scoped)
    end)

    it("applies a transient with no tasktypes to every task type", function()
        local a = makevex("__spec_transient_a", "transient global a")
        local b = makevex("__spec_transient_b", "transient global b")

        assert.equal("global:" .. a, task:present(a).__spec_global)
        assert.equal("global:" .. b, task:present(b).__spec_global)
    end)

    it("can derive from another task via context.taskmanager", function()
        local target = makevex("__spec_transient_b", "transient crosslink target")
        local source = makevex("__spec_transient_a", "transient crosslink source", { linkto = target })

        assert.equal("transient crosslink target", task:present(source).__spec_crosslink)
    end)

    it("never appears in format() output or on the stored task table", function()
        local a = makevex("__spec_transient_a", "transient never stored")

        assert.truthy(task:present(a).__spec_scoped)
        assert.is_nil(task:format(a).__spec_scoped)
        assert.is_nil(task.tasks[a].__spec_scoped)
    end)

    it("is not written to the task's file on disk", function()
        local a = makevex("__spec_transient_a", "transient never on disk")
        local path = task:getabspath(a)
        local fh = assert(io.open(path, "r"))
        local contents = fh:read("*a")
        fh:close()

        assert.falsy(contents:find("__spec_scoped", 1, true))
    end)

end)
