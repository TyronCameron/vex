local cli = require 'lib.cli'

local function run(command)
    local printed = {}
    local quiet = stub(_G, 'print', function(text) table.insert(printed, tostring(text)) end)
    cli:run(command)
    quiet:revert()
    return table.concat(printed, "\n")
end

local function lines(text)
    local set = {}
    for line in text:gmatch("[^\n]+") do set[line] = true end
    return set
end

describe("vexcomplete", function()

    it("prints a completion snippet for each supported shell", function()
        for _, shell in ipairs({"bash", "zsh", "fish", "powershell"}) do
            assert.truthy(run("autocomplete " .. shell):find("vex suggest", 1, true), shell)
        end
    end)

    it("rejects an unknown shell", function()
        local thrown = {}
        stub(cli, 'throw', function(self, name) table.insert(thrown, name) error(name) end)
        pcall(run, "autocomplete nosuchshell")
        cli.throw:revert()
        assert.equal('unknown-shell', thrown[1])
    end)

    it("suggests verbs, then focuses, then views", function()
        assert.truthy(lines(run("suggest 1 vex")).focus)
        assert.truthy(lines(run("suggest 2 vex view")).all)
        assert.truthy(lines(run("suggest 3 vex view all")).kanban)
    end)

    it("suggests recipes for the recipe verb", function()
        assert.truthy(lines(run("suggest 2 vex recipe")).abstract)
    end)

end)
