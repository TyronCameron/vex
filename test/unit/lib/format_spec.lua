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

        it("writes a column for every field of any record, in a stable order, leaving missing values empty", function()
            assert.equal("a,b\n1,\n2,3", format.csv({{a = 1}, {b = 3, a = 2}}))
        end)

        it("writes nothing for no records", function()
            assert.equal("", format.csv({}))
        end)

        it("quotes carriage returns and surrounding whitespace, and keeps unicode and empty strings as they are", function()
            assert.equal('a\n"x\ry"\n" pad"\n"pad "\nè\n', format.csv({{a = 'x\ry'}, {a = ' pad'}, {a = 'pad '}, {a = 'è'}, {a = ''}}))
        end)

        it("writes a list as one cell of comma-separated values", function()
            assert.equal('a\n"x,y"', format.csv({{a = {'x', 'y'}}}))
        end)

        it("quotes a header that needs it", function()
            assert.equal('"a,b"\n1', format.csv({{['a,b'] = 1}}))
        end)

    end)

    describe("ics", function()

        local function ics(...) return format.ics({{...}}, 'prodid') end

        it("wraps events in a calendar, one CRLF-terminated property per line", function()
            assert.equal("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:prodid\r\nCALSCALE:GREGORIAN\r\nBEGIN:VEVENT\r\nUID:a@vex\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n", ics({name = 'UID', value = 'a@vex'}))
        end)

        it("escapes backslashes, semicolons, commas and newlines in text", function()
            assert.truthy(ics({name = 'SUMMARY', value = 'a\\b;c,d\ne', text = true}):find("SUMMARY:a\\\\b\\;c\\,d\\ne\r\n", 1, true))
        end)

        it("writes parameters before the value", function()
            assert.truthy(ics({name = 'DTSTART', params = 'VALUE=DATE', value = '20261201'}):find("DTSTART;VALUE=DATE:20261201\r\n", 1, true))
        end)

        it("folds lines at 75 octets without splitting a character", function()
            local out = ics({name = 'SUMMARY', value = string.rep('è', 60), text = true})
            for line in out:gmatch("[^\r]+") do
                line = line:gsub("^\n", "")
                assert.truthy(#line <= 75)
            end
            assert.truthy(out:find("\r\n è", 1, true))
            assert.equal(string.rep('è', 60), (out:match("SUMMARY:(.-)\r\nEND:VEVENT"):gsub("\r\n ", "")))
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
