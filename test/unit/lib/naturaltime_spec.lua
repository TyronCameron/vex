local naturaltime = require 'lib.naturaltime'

local function at(year, month, day, hour, min)
    return os.time({year = year, month = month, day = day, hour = hour or 0, min = min or 0, sec = 0, isdst = false})
end

local now = at(2026, 10, 17, 10, 30)

describe("naturaltime", function()

    local cases = {
        {"Now", now},
        {"Fifteen minutes", now + 15 * 60},
        {"Half day", now + 12 * 3600},
        {"in 3 days", now + 3 * 86400},
        {"3 days ago", now - 3 * 86400},
        {"an hour and a half", now + 90 * 60},
        {"twenty five minutes", now + 25 * 60},
        {"Tomorrow", at(2026, 10, 18)},
        {"Yesterday", at(2026, 10, 16)},
        {"Tomorrow morning", at(2026, 10, 18, 6)},
        {"Tomorrow arvo", at(2026, 10, 18, 12)},
        {"Morning", at(2026, 10, 18, 6)},
        {"Morn", at(2026, 10, 18, 6)},
        {"First light", at(2026, 10, 18, 6)},
        {"Eve", at(2026, 10, 17, 18)},
        {"Dusk", at(2026, 10, 17, 18)},
        {"tonight", at(2026, 10, 17, 21)},
        {"this morning", at(2026, 10, 17, 6)},
        {"last night", at(2026, 10, 16, 21)},
        {"next weekend", at(2026, 10, 24)},
        {"midnight", at(2026, 10, 18)},
        {"noon tomorrow", at(2026, 10, 18, 12)},
        {"tomorrow at 3:30pm", at(2026, 10, 18, 15, 30)},
        {"5pm", at(2026, 10, 17, 17)},
        {"at 9", at(2026, 10, 18, 9)},
        {"Wed", at(2026, 10, 21)},
        {"Next Tuesday", at(2026, 10, 20)},
        {"last tuesday", at(2026, 10, 13)},
        {"saturday", at(2026, 10, 24)},
        {"next week", at(2026, 10, 19)},
        {"next month", at(2026, 11, 1)},
        {"last month", at(2026, 9, 1)},
        {"Next year", at(2027, 1, 1)},
        {"Last year", at(2025, 1, 1)},
        {"this year", at(2026, 1, 1)},
        {"Next fall", at(2027, 9, 1)},
        {"winter", at(2026, 12, 1)},
        {"By 26 July", at(2027, 7, 26)},
        {"Before 26 July", at(2027, 7, 26)},
        {"July 26th", at(2027, 7, 26)},
        {"the 26th of december 2026", at(2026, 12, 26)},
        {"the 17th", at(2026, 10, 17)},
        {"2026-12-25", at(2026, 12, 25)},
        {"2026-12-25 09:15", at(2026, 12, 25, 9, 15)},
    }

    for _, case in ipairs(cases) do
        it("reads `" .. case[1] .. "`", function()
            assert.equal(os.date("%Y-%m-%d %H:%M", case[2]), os.date("%Y-%m-%d %H:%M", naturaltime.parse(case[1], now)))
        end)
    end

    it("reads the current time by default", function()
        assert.truthy(math.abs(naturaltime.parse("now") - os.time()) <= 1)
    end)

    it("rejects a phrase with words it does not know, naming them", function()
        local ok, err = pcall(naturaltime.parse, "tomorrow blorp", now)
        assert.is_false(ok)
        assert.truthy(err:find("blorp", 1, true))
    end)

    it("rejects a relation with nothing to relate to", function()
        assert.is_false(pcall(naturaltime.parse, "next", now))
    end)

    it("describes a time relative to now in words it reads back", function()
        for _, case in ipairs({{now, "now"}, {now + 3 * 86400, "in 3 days"}, {now - 2 * 3600, "2 hours ago"}, {now + 60, "in 1 minute"}}) do
            assert.equal(case[2], naturaltime.describe(case[1], now))
            assert.equal(case[1], naturaltime.parse(case[2], now))
        end
    end)

end)
