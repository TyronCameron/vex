local EventManager = getmetatable(require 'lib.event')

describe("EventManager", function()

    local event

    before_each(function()
        event = EventManager.new()
    end)

    it("passes the trigger's args to each handler", function()
        local received
        event:register('ping', 'spec', function(...) received = {...} end)
        event:trigger('ping', 1, 'two')
        assert.same({1, 'two'}, received)
    end)

    it("runs handlers in the order they were registered", function()
        local order = {}
        event:register('ping', 'first', function() table.insert(order, 'first') end)
        event:register('ping', 'second', function() table.insert(order, 'second') end)
        event:register('ping', 'third', function() table.insert(order, 'third') end)
        event:trigger('ping')
        assert.same({'first', 'second', 'third'}, order)
    end)

    it("replaces a handler registered again under the same handle, keeping its place", function()
        local order = {}
        event:register('ping', 'first', function() table.insert(order, 'old') end)
        event:register('ping', 'second', function() table.insert(order, 'second') end)
        event:register('ping', 'first', function() table.insert(order, 'new') end)
        event:trigger('ping')
        assert.same({'new', 'second'}, order)
    end)

    it("uses the callback as its own handle when none is given", function()
        local calls = 0
        local function handler() calls = calls + 1 end
        assert.equal(handler, event:register('ping', handler))
        event:remove('ping', handler)
        event:trigger('ping')
        assert.equal(0, calls)
    end)

    it("registers a handler with on", function()
        local received
        event:on 'ping' (function(value) received = value end)
        event:trigger('ping', 'pong')
        assert.equal('pong', received)
    end)

    it("removes a handler", function()
        local calls = 0
        event:register('ping', 'spec', function() calls = calls + 1 end)
        event:remove('ping', 'spec')
        event:trigger('ping')
        assert.equal(0, calls)
    end)

    it("refuses to remove an unknown event or handle", function()
        assert.has_error(function() event:remove('nothing', 'spec') end)
        event:register('ping', 'spec', function() end)
        assert.has_error(function() event:remove('ping', 'other') end)
    end)

    it("ignores events nobody listens to", function()
        assert.has_no.errors(function() event:trigger('nothing', 1) end)
    end)

    it("gives * handlers every event, with its name first", function()
        local received = {}
        event:register('*', 'spec', function(...) table.insert(received, {...}) end)
        event:trigger('ping', 1)
        event:trigger('pong')
        assert.same({{'ping', 1}, {'pong'}}, received)
    end)

    it("raises a hook error naming the failing handle and event", function()
        event:register('ping', 'spec', function() error('boom') end)
        local ok, err = pcall(event.trigger, event, 'ping')
        assert.is_false(ok)
        assert.is_true(EventManager.ishookerror(err))
        assert.equal('ping', err.event)
        assert.equal('spec', err.hook)
        assert.truthy(tostring(err.err):find('boom', 1, true))
    end)

    it("names a handler without a handle by where it was defined", function()
        event:on 'ping' (function() error('boom') end)
        local _, err = pcall(event.trigger, event, 'ping')
        assert.truthy(err.hook:find('event_spec.lua:%d+'))
    end)

    it("stops at the first failing handler", function()
        local ran = false
        event:register('ping', 'broken', function() error('boom') end)
        event:register('ping', 'after', function() ran = true end)
        pcall(event.trigger, event, 'ping')
        assert.is_false(ran)
    end)

    it("does not mistake other errors for hook errors", function()
        assert.is_false(EventManager.ishookerror('boom'))
        assert.is_false(EventManager.ishookerror({}))
    end)

end)
