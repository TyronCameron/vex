local format = require 'lib.format'

describe("format", function()

    describe("csv", function()

        it("writes a header and one row per record", function()
            local lines = {}
            for line in format.csv({{a = 1}, {a = 2}}):gmatch("[^\n]+") do table.insert(lines, line) end
            assert.same({"a", "1", "2"}, lines)
        end)

        it("quotes fields holding commas, quotes or newlines", function()
            assert.equal('a\n"x, ""y""\nz"', format.csv({{a = 'x, "y"\nz'}}))
        end)

        it("writes nothing for no records", function()
            assert.equal("", format.csv({}))
        end)

    end)

    describe("json", function()

        it("writes arrays, objects and escaped strings", function()
            assert.equal('[\n  1,\n  "a\\"b"\n]', format.json({1, 'a"b'}))
            assert.equal('{\n  "k": true\n}', format.json({k = true}))
        end)

        it("writes empty tables as an empty array", function()
            assert.equal('[]', format.json({}))
        end)

    end)

end)
