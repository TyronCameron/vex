local lfs = require 'lib.lfs'

local function tmpdir()
    local handle = io.popen("mktemp -d")
    local dir = handle:read("*l")
    handle:close()
    return dir
end

describe("lfs", function()

    it("makes folders and tells folders, files and missing paths apart", function()
        local dir = tmpdir()
        lfs.mkdir(dir .. "/made")
        io.open(dir .. "/file.txt", "w"):close()
        assert.equal("directory", lfs.attributes(dir .. "/made", "mode"))
        assert.equal("file", lfs.attributes(dir .. "/file.txt", "mode"))
        assert.is_nil(lfs.attributes(dir .. "/missing"))
        os.execute("rm -rf '" .. dir .. "'")
    end)

    it("lists a folder's entries", function()
        local dir = tmpdir()
        io.open(dir .. "/one.txt", "w"):close()
        local entries = {}
        for entry in lfs.dir(dir) do entries[entry] = true end
        assert.truthy(entries["one.txt"])
        assert.truthy(entries["."])
        os.execute("rm -rf '" .. dir .. "'")
    end)

    it("knows the current folder", function()
        assert.truthy(lfs.attributes(lfs.currentdir() .. "/.vex", "mode"))
    end)

end)
