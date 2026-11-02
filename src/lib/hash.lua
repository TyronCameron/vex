local bit = require 'bit'

local hash = {}

function hash.fnv1a(str)
    local h = 0x811c9dc5
    for i = 1, #str do
        h = bit.bxor(h, str:byte(i))
        h = bit.tobit(h * 403 + bit.lshift(h, 24))
    end
    return bit.tohex(h)
end

return hash
