local StateMachine = {}
StateMachine.__index = StateMachine

local function set(tab)
    local s = {}
    for _, v in ipairs(tab) do s[v] = true end
    return s
end

-- Normalise valid/invalid declarations into a single `valid` set per state
local function preprocess(def)
    for name, state in pairs(def) do
        assert(not (state.valid and state.invalid),
            "state '" .. name .. "': specify valid OR invalid, not both")

        if state.valid then
            state.valid = set(state.valid)
        elseif state.invalid then
            local invalid = set(state.invalid)
            state.valid = {}
            for n in pairs(def) do
                if not invalid[n] then state.valid[n] = true end
            end
            state.invalid = nil
        else
            state.valid = {} -- nothing valid 
        end
    end
    return def
end

function StateMachine.new(def, currentstate)
    local this = setmetatable({
        states = preprocess(def),
        current = nil,
        history = {}
    }, StateMachine)
    this:transition(currentstate)
    return this
end

function StateMachine:isvalid(to)
    if not self.states[to] then
        return false, "'" .. tostring(to) .. "' is not a defined state for this statemachine"
    end
    if self.current == to then return true end
    if not self.current then return true end 
    if self.states[self.current].valid[to] then return true end
    return false, "invalid transition from '" .. self.current .. "' to '" .. to .. "'"
end

function StateMachine:isdone()
    if not self.current then return false end 
    for _ in pairs(self.states[self.current]) do
        return false
    end
    return true 
end

function StateMachine:transition(to, ...)
    if self.current == to then return true end
    local ok, err = self:isvalid(to)
    if not ok then return false, err end

    if self.current and self.states[self.current].exit then
        self.states[self.current].exit(self.current, to, ...)
    end

    local prev = self.current
    self.current = to
    table.insert(self.history, to)

    if self.states[self.current].enter then
        self.states[self.current].enter(prev, to, ...)
    end

    return true
end

return StateMachine