local busted = require 'busted'
local statemachine = require 'lib.statemachine'

describe("statemachine", function()

    local states = {
        todo = { valid = {"doing"} },
        doing = { valid = {"done"} },
        done = { valid = {} },
    }

    it("knows its initial state", function()
        local machine = statemachine.new(states, "doing", "todo")
        assert.is_true(machine:isinitial("todo"))
        assert.is_false(machine:isinitial())
    end)

    it("treats a state with no outgoing transitions as final", function()
        local machine = statemachine.new(states, "done", "todo")
        assert.is_true(machine:isfinal())
        assert.is_false(machine:isfinal("doing"))
    end)

    it("does not count a transition to itself as outgoing", function()
        local machine = statemachine.new({
            open = { invalid = {} },
            closed = { invalid = {"open"} },
        }, "closed", "open")
        assert.is_true(machine:isfinal())
        assert.is_false(machine:isfinal("open"))
    end)

    it("counts the fewest moves from the initial state to each state", function()
        local machine = statemachine.new({
            todo = { valid = {"doing", "done"} },
            doing = { valid = {"review"} },
            review = { valid = {"done"} },
            done = { valid = {} },
        }, "todo", "todo")
        assert.same({todo = 0, doing = 1, done = 1, review = 2}, machine:distances())
    end)

    it("treats anything neither initial nor final as interim", function()
        local machine = statemachine.new(states, "doing", "todo")
        assert.is_true(machine:isinterim())
        assert.is_false(machine:isinterim("todo"))
        assert.is_false(machine:isinterim("done"))
    end)

end)
