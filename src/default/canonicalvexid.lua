-- Filler words to ignore
local filler_words = {
    the = true, a = true, an = true, ["and"] = true, ["or"] = true, but = true,
    ["for"] = true, of = true, ["in"] = true, on = true, at = true, to = true,
    with = true, from = true, by = true, is = true, are = true, was = true,
    were = true, be = true, been = true, being = true, have = true, has = true,
    had = true, ["do"] = true, does = true, did = true, will = true, would = true,
    should = true, could = true, may = true, might = true, must = true, 
    can = true, ["then"] = true, than = true, that = true, this = true,
    these = true, those = true, ["if"] = true, ["else"] = true, as = true, so = true,
    all = true, each = true, every = true, both = true, just = true, only = true
}


return {
    generate = function(str, lookup)
        -- Split string into words and filter out filler words
        local words = {}
        for word in str:gmatch("%S+") do
            local clean_word = word:lower():gsub("[^a-z0-9]", "")
            if clean_word ~= "" and not filler_words[clean_word] then
                table.insert(words, clean_word)
            end
        end
        -- Take up to 4 words (or 3 if less available)
        local tag_words = {}
        local max_words = math.min(4, #words)
        for i = 1, max_words do
            table.insert(tag_words, words[i])
        end
        -- Join with hyphens
        local tag = table.concat(tag_words, "-")
        local counter = 1
        while lookup[tag .. "-" .. counter] do 
            counter = counter + 1
        end 
        return tag .. "-" .. counter
    end 
}