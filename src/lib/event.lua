local EventManager = {}
EventManager.__index = EventManager

local HookError = {}

function EventManager.new()
    local self = {
        triggers = {}
    }
    return setmetatable(self, EventManager)
end

function EventManager.ishookerror(err)
    return getmetatable(err) == HookError
end

local function find(trig, handle)
    for i, handler in ipairs(trig) do
        if handler.handle == handle then return i end
    end
end

function EventManager:register(event, handle, callback)
    if not callback then
        callback = handle
    end

    assert(type(callback) == 'function', 'provided callback must be a function!')
    assert(type(event) == 'string', 'event must be a string')

    local trig = self.triggers[event]
    if not trig then
        trig = {}
        self.triggers[event] = trig
    end

    local handler = {handle = handle, callback = callback}
    trig[find(trig, handle) or #trig + 1] = handler
    return handle
end

function EventManager:on(event)
    return function(callback)
        return self:register(event, callback)
    end
end

local function name(handler)
    if type(handler.handle) ~= 'function' then return tostring(handler.handle) end
    local info = debug.getinfo(handler.callback, 'S')
    return info.short_src .. ':' .. info.linedefined
end

local function run(handlers, event, ...)
    for _, handler in ipairs(handlers or {}) do
        local ok, err = pcall(handler.callback, ...)
        if not ok and EventManager.ishookerror(err) then
            error(err, 0)
        elseif not ok then
            error(setmetatable({event = event, hook = name(handler), err = err}, HookError), 0)
        end
    end
end

function EventManager:trigger(event, ...)
    assert(type(event) == 'string', 'event must be a string')
    run(self.triggers[event], event, ...)
    run(self.triggers['*'], event, event, ...)
end

function EventManager:remove(event, handle)
    assert(type(event) == 'string', 'event must be a string')
    local trig = assert(self.triggers[event], 'no event ' .. event)
    table.remove(trig, assert(find(trig, handle), 'no callback with this handle'))
end

return EventManager.new()
