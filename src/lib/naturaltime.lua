local naturaltime = {}

local numbers = {
    a = 1, an = 1, one = 1, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8, nine = 9,
    ten = 10, eleven = 11, twelve = 12, thirteen = 13, fourteen = 14, fifteen = 15, sixteen = 16,
    seventeen = 17, eighteen = 18, nineteen = 19, twenty = 20, thirty = 30, forty = 40, fifty = 50,
    sixty = 60, seventy = 70, eighty = 80, ninety = 90, half = 0.5, couple = 2, few = 3, dozen = 12,
}

local units = {
    second = {'sec', 1}, sec = {'sec', 1}, minute = {'sec', 60}, min = {'sec', 60},
    hour = {'sec', 3600}, hr = {'sec', 3600}, day = {'day', 1}, week = {'day', 7}, wk = {'day', 7},
    fortnight = {'day', 14}, month = {'month', 1}, year = {'month', 12}, yr = {'month', 12},
}

local clocks = {
    dawn = 6, daybreak = 6, sunrise = 6, morning = 6, morn = 6,
    midday = 12, noon = 12, lunch = 12, lunchtime = 12, afternoon = 12, arvo = 12,
    eod = 17, cob = 17, evening = 18, eve = 18, dusk = 18, sunset = 18, twilight = 18,
    night = 21, midnight = 24,
}

local days = {today = 0, tomorrow = 1, tmrw = 1, tmr = 1, yesterday = -1}

local weekdays = {
    sunday = 1, sun = 1, monday = 2, mon = 2, tuesday = 3, tue = 3, tues = 3,
    wednesday = 4, wed = 4, weds = 4, thursday = 5, thu = 5, thur = 5, thurs = 5,
    friday = 6, fri = 6, saturday = 7, sat = 7, weekend = 7,
}

local months = {
    january = 1, jan = 1, february = 2, feb = 2, march = 3, mar = 3, april = 4, apr = 4, may = 5,
    june = 6, jun = 6, july = 7, jul = 7, august = 8, aug = 8, september = 9, sep = 9, sept = 9,
    october = 10, oct = 10, november = 11, nov = 11, december = 12, dec = 12,
}

local seasons = {spring = 3, summer = 6, autumn = 9, fall = 9, winter = 12}

local relations = {next = 1, coming = 1, upcoming = 1, this = 0, last = -1, previous = -1, past = -1}

local fillers = {}
for _, word in ipairs {'by', 'before', 'on', 'at', 'in', 'the', 'of', 'until', 'till', 'til', 'due', 'from', 'and', "o'clock", 'oclock', 'later', 'around', 'about'} do
    fillers[word] = true
end

local aliases = {
    {'first light', 'dawn'}, {'end of day', 'eod'}, {'close of business', 'cob'}, {'and a half', 'andahalf'},
}

local function tokenize(phrase)
    phrase = ' ' .. phrase:lower():gsub('[,;]', ' ') .. ' '
    for _, alias in ipairs(aliases) do
        phrase = phrase:gsub('%s' .. alias[1]:gsub(' ', '%%s+') .. '%s', ' ' .. alias[2] .. ' ')
    end
    local tokens = {}
    for word in phrase:gmatch('%S+') do
        if word:match('^%d%d%d%d%-%d%d%-%d%d$') then
            table.insert(tokens, word)
        else
            for part in word:gmatch('[^%-]+') do table.insert(tokens, part) end
        end
    end
    return tokens
end

local function unit(word)
    return word and (units[word] or units[(word:gsub('s$', ''))])
end

-- local calendar fields to a timestamp, the same way the datetime format iso reads them
local function moment(fields)
    return os.time({year = fields.year, month = fields.month, day = fields.day, hour = 0, min = 0, sec = fields.sec or 0, isdst = false})
end

local spill = {month = {'day', 30}, day = {'sec', 86400}}

local function lengthen(shift, field, amount)
    local whole = amount < 0 and math.ceil(amount) or math.floor(amount)
    shift[field] = shift[field] + whole
    if amount ~= whole and spill[field] then
        lengthen(shift, spill[field][1], (amount - whole) * spill[field][2])
    end
end

local function number(tokens, i)
    local value = tonumber(tokens[i]) or numbers[tokens[i]]
    if not value then return end
    local consumed = 1
    local ones = numbers[tokens[i + 1]]
    if value >= 20 and value % 10 == 0 and ones and ones >= 1 and ones < 10 then
        value, consumed = value + ones, 2
    end
    if tokens[i + consumed] == 'andahalf' then
        value, consumed = value + 0.5, consumed + 1
    end
    return value, consumed
end

local function today(state)
    return os.date('*t', state.now)
end

local function setday(state, offset)
    local t = today(state)
    local day = os.date('*t', moment {year = t.year, month = t.month, day = t.day + offset})
    state.date = {year = day.year, month = day.month, day = day.day}
end

local function sethour(state, hour)
    state.clock = hour * 3600
end

-- the next (or, for a negative relation, previous) start of a yearly date strictly after (or before) today
local function yearly(state, month, relation)
    local t = today(state)
    local start, now = moment {year = t.year, month = month, day = 1}, moment {year = t.year, month = t.month, day = t.day}
    local year = t.year
    if relation == -1 and start >= now then year = year - 1 end
    if relation ~= -1 and start <= now then year = year + 1 end
    state.date = {year = year, month = month, day = 1}
end

local function anchor(state, word, relation)
    local t = today(state)
    if weekdays[word] then
        local ahead = (weekdays[word] - t.wday) % 7
        local behind = (t.wday - weekdays[word]) % 7
        if relation == -1 then setday(state, behind == 0 and -7 or -behind)
        else setday(state, ahead == 0 and 7 or ahead) end
    elseif seasons[word] then
        yearly(state, seasons[word], relation)
    elseif months[word] and relation == -1 then
        yearly(state, months[word], relation)
        state.date.day = nil
    elseif months[word] then
        state.date.month = months[word]
    elseif not relation then
        return false
    elseif clocks[word] then
        setday(state, relation)
        sethour(state, clocks[word])
    elseif word == 'day' then
        setday(state, relation)
    elseif word == 'week' or word == 'fortnight' then
        setday(state, -((t.wday - 2) % 7) + relation * units[word][2])
    elseif word == 'month' then
        state.date = {year = t.year, month = t.month + relation, day = 1}
    elseif word == 'year' then
        state.date = {year = t.year + relation, month = 1, day = 1}
    elseif unit(word) and unit(word)[1] == 'sec' then
        lengthen(state.shift, 'sec', relation * unit(word)[2])
    else
        return false
    end
    return true
end

local ordinals = {st = true, nd = true, rd = true, th = true}

local function clock(word)
    local h, m, s = word:match('^(%d%d?):(%d%d):?(%d?%d?)$')
    if h then return tonumber(h), tonumber(m), tonumber(s) end
    local meridiem
    h, m, meridiem = word:match('^(%d%d?):?(%d*)([ap]m)$')
    if h then return tonumber(h) % 12 + (meridiem == 'pm' and 12 or 0), tonumber(m) end
end

-- each rule reads the tokens at i into the state and returns how many it consumed, or nil

local function isodate(tokens, i, state)
    local y, m, d = tokens[i]:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not y then return end
    state.date = {year = tonumber(y), month = tonumber(m), day = tonumber(d)}
    return 1
end

local function clocktime(tokens, i, state)
    local consumed = 1
    local h, m, s = clock(tokens[i])
    if not h and tonumber(tokens[i]) and (tokens[i + 1] == 'am' or tokens[i + 1] == 'pm') then
        h, m = clock(tokens[i] .. tokens[i + 1])
        consumed = 2
    end
    if not h then return end
    state.clock = h * 3600 + (m or 0) * 60 + (s or 0)
    return consumed
end

local function timeofday(tokens, i, state)
    if not clocks[tokens[i]] then return end
    sethour(state, clocks[tokens[i]])
    return 1
end

local function namedday(tokens, i, state)
    if tokens[i] == 'now' then return 1 end
    if tokens[i] == 'tonight' then
        setday(state, 0)
        sethour(state, clocks.night)
        return 1
    end
    if not days[tokens[i]] then return end
    setday(state, days[tokens[i]])
    return 1
end

local function relative(tokens, i, state)
    local relation = relations[tokens[i]]
    if relation and tokens[i + 1] and anchor(state, tokens[i + 1], relation) then return 2 end
end

local function anchored(tokens, i, state)
    if anchor(state, tokens[i]) then return 1 end
end

local function duration(tokens, i, state)
    local value, consumed = number(tokens, i)
    local u = value and unit(tokens[i + consumed])
    if not u then return end
    lengthen(state.shift, u[1], value * u[2])
    consumed = consumed + 1
    if tokens[i + consumed] == 'andahalf' then
        lengthen(state.shift, u[1], 0.5 * u[2])
        consumed = consumed + 1
    end
    return consumed
end

local function dayofmonth(tokens, i, state)
    local day, suffix = tokens[i]:match('^(%d%d?)(%a*)$')
    local besidemonth = months[tokens[i + 1] or ''] or months[tokens[i - 1] or '']
    if not (day and (ordinals[suffix] or (suffix == '' and besidemonth))) then return end
    state.date.day = tonumber(day)
    return 1
end

local function calendaryear(tokens, i, state)
    if not tokens[i]:match('^%d%d%d%d$') then return end
    state.date.year = tonumber(tokens[i])
    return 1
end

local function athour(tokens, i, state)
    local hour = tokens[i] == 'at' and tonumber(tokens[i + 1] or '')
    if not (hour and hour <= 24 and not unit(tokens[i + 2]) and not months[tokens[i + 2] or '']) then return end
    sethour(state, hour)
    return 2
end

local function ago(tokens, i, state)
    if tokens[i] ~= 'ago' then return end
    state.ago = true
    return 1
end

local function filler(tokens, i)
    if fillers[tokens[i]] then return 1 end
end

local rules = {isodate, clocktime, timeofday, namedday, relative, anchored, duration, dayofmonth, calendaryear, athour, ago, filler}

local function settle(state)
    local t = today(state)
    local midnight = moment {year = t.year, month = t.month, day = t.day}
    local date = state.date
    local base = state.now
    if date.year or date.month or date.day then
        local fields = {year = date.year or t.year, month = date.month or (date.year and 1) or t.month, day = date.day or 1}
        if not date.year and moment(fields) < midnight then
            if date.month then fields.year = fields.year + 1 else fields.month = fields.month + 1 end
        end
        base = moment(fields) + (state.clock or 0)
    elseif state.clock then
        base = midnight + state.clock
        if base <= state.now then base = moment {year = t.year, month = t.month, day = t.day + 1} + state.clock end
    end
    local sign = state.ago and -1 or 1
    local shifted = os.date('*t', base)
    shifted.month = shifted.month + sign * state.shift.month
    shifted.day = shifted.day + sign * state.shift.day
    shifted.sec = shifted.sec + sign * state.shift.sec
    return os.time(shifted)
end

-- reads a phrase such as "tomorrow arvo", "next tuesday" or "in 3 days" as a timestamp relative to now
function naturaltime.parse(phrase, now)
    local state = {now = now or os.time(), date = {}, shift = {month = 0, day = 0, sec = 0}}
    local tokens = tokenize(phrase)
    local unknown = {}
    local i = 1
    while i <= #tokens do
        local consumed
        for _, rule in ipairs(rules) do
            consumed = rule(tokens, i, state)
            if consumed then break end
        end
        if not consumed then table.insert(unknown, tokens[i]) end
        i = i + (consumed or 1)
    end
    if #unknown > 0 then error('Cannot interpret `' .. tostring(phrase) .. '` as a time. Unknown words: ' .. table.concat(unknown, ', ') .. '. Try a phrase such as `tomorrow`, `next tuesday`, `friday arvo`, `in 3 days`, `26 July` or `2026-07-26 09:00`.', 0) end
    return settle(state)
end

local scales = {{'year', 31536000}, {'month', 2592000}, {'week', 604800}, {'day', 86400}, {'hour', 3600}, {'minute', 60}}

-- describes a timestamp relative to now, to the nearest whole unit
function naturaltime.describe(epoch, now)
    local delta = epoch - (now or os.time())
    for _, scale in ipairs(scales) do
        if math.abs(delta) >= scale[2] then
            local count = math.floor(math.abs(delta) / scale[2] + 0.5)
            local amount = count .. ' ' .. scale[1] .. (count == 1 and '' or 's')
            return delta > 0 and 'in ' .. amount or amount .. ' ago'
        end
    end
    return 'now'
end

return naturaltime
