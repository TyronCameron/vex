local StateMachine = {}
StateMachine.__index = StateMachine

local function set(tab)
    local s = {}
    for _, v in ipairs(tab) do s[v] = true end
    return s
end

-- Normalise valid/invalid declarations into a single `valid` set per state
local function preprocess(def)
    local states = {}
    for name, original in pairs(def) do
        local state = {}
        for k, v in pairs(original) do state[k] = v end
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
        states[name] = state
    end
    return states
end

function StateMachine.new(def, currentstate, initial)
    local this = setmetatable({
        states = preprocess(def),
        initial = initial,
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

function StateMachine:isinitial(state)
    return (state or self.current) == self.initial
end

function StateMachine:isfinal(state)
    state = state or self.current
    for to in pairs(self.states[state].valid) do
        if to ~= state then return false end
    end
    return true
end

function StateMachine:isinterim(state)
    return not self:isinitial(state) and not self:isfinal(state)
end

-- the fewest moves from the initial state to each state that can be reached
function StateMachine:distances()
    local distances = {[self.initial] = 0}
    local queue = {self.initial}
    for _, state in ipairs(queue) do
        for to in pairs(self.states[state].valid) do
            if not distances[to] then
                distances[to] = distances[state] + 1
                table.insert(queue, to)
            end
        end
    end
    return distances
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