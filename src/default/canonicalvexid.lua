local maxchars, maxwords = 32, 6

local function set(words)
    local t = {}
    for word in words:gmatch("%a+") do t[word] = true end
    return t
end

local filler = set [[
    a an the this that these those some any each every all both either neither
    i me my we us our you your he him his she her it its they them their
    what which who whom whose where why how
    is are was were be been being am have has had do does did done
    will would shall should could can may might must
    very really actually just only also still even too quite rather already always ever again
    and or nor but so yet then else etc
]]

local boundary = set [[
    of in on at to into onto from by with without within for about over under above below
    between through across after before during since until upon via per than as like
    outside inside around against along among toward towards beyond including
    when while because if unless though although whether
]]

local negated = set [[
    isnt arent wasnt werent dont doesnt didnt hasnt havent hadnt
    wont wouldnt cant couldnt shouldnt mustnt
]]

local folds = {
    ["à"] = "a", ["á"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a", ["å"] = "a", ["æ"] = "ae",
    ["À"] = "a", ["Á"] = "a", ["Â"] = "a", ["Ã"] = "a", ["Ä"] = "a", ["Å"] = "a", ["Æ"] = "ae",
    ["ç"] = "c", ["Ç"] = "c", ["ñ"] = "n", ["Ñ"] = "n", ["ß"] = "ss", ["œ"] = "oe", ["Œ"] = "oe",
    ["è"] = "e", ["é"] = "e", ["ê"] = "e", ["ë"] = "e", ["È"] = "e", ["É"] = "e", ["Ê"] = "e", ["Ë"] = "e",
    ["ì"] = "i", ["í"] = "i", ["î"] = "i", ["ï"] = "i", ["Ì"] = "i", ["Í"] = "i", ["Î"] = "i", ["Ï"] = "i",
    ["ò"] = "o", ["ó"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o", ["ø"] = "o",
    ["Ò"] = "o", ["Ó"] = "o", ["Ô"] = "o", ["Õ"] = "o", ["Ö"] = "o", ["Ø"] = "o",
    ["ù"] = "u", ["ú"] = "u", ["û"] = "u", ["ü"] = "u", ["Ù"] = "u", ["Ú"] = "u", ["Û"] = "u", ["Ü"] = "u",
    ["ý"] = "y", ["ÿ"] = "y", ["Ý"] = "y",
    ["‘"] = "'", ["’"] = "'", ["“"] = " ", ["”"] = " ", ["–"] = " ", ["—"] = " ", ["…"] = ". ", ["。"] = ". ",
}

local function fold(str)
    return (str:gsub("[\194-\244][\128-\191]*", function(char) return folds[char] end))
end

local function length(word)
    return select(2, word:gsub("[^\128-\191]", ""))
end

local function normalise(str)
    return fold(str):lower()
        :gsub("[%.!?]%s.*$", "")
        :gsub("'s%f[%A]", "")
        :gsub("'", "")
end

local function words(str)
    local all, content, tier = {}, {}, 1
    for chunk in normalise(str):gmatch("[^%s,;:%(%)]+") do
        chunk = chunk:gsub("/.*$", "")
        for word in chunk:gmatch("[%w\128-\255]+") do
            if negated[word] then word = "not" end
            table.insert(all, word)
            if boundary[word] then
                tier = tier + 1
            elseif not filler[word] and not (#word > 5 and word:match("^%a+ly$")) then
                table.insert(content, { word = word, tier = tier })
            end
        end
    end
    return all, content
end

local function fit(content)
    local keep, size, count = {}, -1, 0
    for tier = 1, content[#content].tier do
        for i, entry in ipairs(content) do
            if entry.tier == tier then
                local fits = count < 2 or size + 1 + length(entry.word) <= maxchars
                if count == maxwords or not fits then return keep end
                keep[i] = true
                size = size + 1 + length(entry.word)
                count = count + 1
            end
        end
    end
    return keep
end

local function pick(content)
    local keep = fit(content)
    local chosen = {}
    for i, entry in ipairs(content) do
        if keep[i] then table.insert(chosen, entry.word) end
    end
    return chosen
end

return {
    generate = function(str, lookup)
        local all, content = words(str)
        local chosen = #content > 0 and pick(content) or all
        local tag = #chosen > 0 and table.concat(chosen, "-") or "task"
        local counter = 1
        while lookup[tag .. "-" .. counter] do
            counter = counter + 1
        end
        return tag .. "-" .. counter
    end
}
