local cli = require 'lib.cli'
local lfsext = require 'lib.lfsext'

local src = debug.getinfo(1, "S").source:match("^@(.+[\\/])") .. "../../../src"

local function thrown_errors()
    local thrown = {}
    for _, path in ipairs(lfsext.walk(src)) do
        if path:match("%.lua$") then
            local code = io.open(path):read("*a")
            for name in code:gmatch(":throw%s*%(?%s*['\"]([%w-]+)['\"]") do
                thrown[name] = path:match("src/.*")
            end
        end
    end
    return thrown
end

describe("errors", function()

    it("registers every error that src throws", function()
        local thrown = thrown_errors()
        assert.truthy(next(thrown))
        for name, path in pairs(thrown) do
            assert.truthy(cli.errors[name], "`" .. name .. "` is thrown in " .. path .. " but never registered")
        end
    end)

    it("formats every registered error as a string", function()
        for name, err in pairs(cli.errors) do
            local ok, message = pcall(err[1], "a", "b", "c", "d")
            assert.is_true(ok, "`" .. name .. "` crashed while formatting: " .. tostring(message))
            assert.is_string(message, "`" .. name .. "` did not return a message")
        end
    end)

end)
