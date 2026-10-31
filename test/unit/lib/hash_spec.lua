local hash = require 'lib.hash'

describe("hash", function()

    it("gives the FNV-1a hash of a string as hex", function()
        assert.equal("811c9dc5", hash.fnv1a(""))
        assert.equal("e40c292c", hash.fnv1a("a"))
        assert.equal("bf9cf968", hash.fnv1a("foobar"))
    end)

    it("tells strings that differ by one character apart", function()
        assert.not_equal(hash.fnv1a("cost: 5\n"), hash.fnv1a("cost: 6\n"))
    end)

end)
