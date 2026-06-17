local busted = require 'busted'
local vexdex = require 'core.vexdex'

describe("vexdex", function()

    it("singleton loads and is truthy", function()
        assert.truthy(vexdex)
    end)

    it("unsafe_add stores a path retrievable via get", function()
        vexdex:unsafe_add("__spec-id-1", "/some/path.md")
        assert.equal("/some/path.md", vexdex:get("__spec-id-1"))
        vexdex:unsafe_remove("__spec-id-1")
    end)

    it("get returns nil for a missing id", function()
        assert.is_nil(vexdex:get("__nonexistent-id-xyz"))
    end)

    it("unsafe_remove removes the entry so get returns nil", function()
        vexdex:unsafe_add("__spec-id-2", "/other/path.md")
        vexdex:unsafe_remove("__spec-id-2")
        assert.is_nil(vexdex:get("__spec-id-2"))
    end)

    it("vexpath returns a string containing the argument", function()
        local p = vexdex:vexpath("foo")
        assert.is_string(p)
        assert.truthy(p:find("foo", 1, true))
    end)

    it("multiple unsafe_add calls accumulate independently", function()
        vexdex:unsafe_add("__multi-1", "/path/a.md")
        vexdex:unsafe_add("__multi-2", "/path/b.md")
        assert.equal("/path/a.md", vexdex:get("__multi-1"))
        assert.equal("/path/b.md", vexdex:get("__multi-2"))
        vexdex:unsafe_remove("__multi-1")
        vexdex:unsafe_remove("__multi-2")
    end)

    it("unsafe_remove on a missing id does not error", function()
        assert.has_no.errors(function()
            vexdex:unsafe_remove("__id-that-does-not-exist")
        end)
    end)

    it("index is clean after add then remove", function()
        vexdex:unsafe_add("__clean-test", "/tmp/clean.md")
        vexdex:unsafe_remove("__clean-test")
        assert.is_nil(vexdex:get("__clean-test"))
    end)

end)
