local lfsext = require 'lib.lfsext'

local function tmpdir()
    local handle = io.popen("mktemp -d")
    local dir = handle:read("*l")
    handle:close()
    return dir
end

describe("lfsext", function()

    it("finds the closest folder holding a .vex from anywhere below it", function()
        local dir = tmpdir()
        os.execute("mkdir -p '" .. dir .. "/.vex' '" .. dir .. "/a/b'")
        assert.equal(dir, lfsext.rootdir(dir .. "/a/b"))
        os.execute("rm -rf '" .. dir .. "'")
    end)

    it("walks every file below a folder", function()
        local dir = tmpdir()
        os.execute("mkdir -p '" .. dir .. "/a' && touch '" .. dir .. "/top.md' '" .. dir .. "/a/nested.md'")
        local files = lfsext.walk(dir)
        table.sort(files)
        assert.same({dir .. "/a/nested.md", dir .. "/top.md"}, files)
        os.execute("rm -rf '" .. dir .. "'")
    end)

end)
