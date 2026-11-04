local lfsext = require 'lib.lfsext'
local lfs = require 'lib.lfs'

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

    it("makes a folder with every missing folder above it, and accepts one that exists", function()
        local dir = tmpdir()
        assert.truthy(lfsext.mkdirs(dir .. "/a/b/c"))
        assert.equal("directory", lfs.attributes(dir .. "/a/b/c", "mode"))
        assert.truthy(lfsext.mkdirs(dir .. "/a/b"))
        os.execute("rm -rf '" .. dir .. "'")
    end)

    it("lists the mtime of every file below a folder, skipping hidden ones", function()
        local dir = tmpdir()
        os.execute("mkdir -p '" .. dir .. "/a' '" .. dir .. "/.hidden' && touch '" .. dir .. "/top.md' '" .. dir .. "/a/nested.md' '" .. dir .. "/.hidden/skip.md' '" .. dir .. "/.skip.md'")
        local mtimes = lfsext.mtimes(dir)
        local paths = {}
        for path in pairs(mtimes) do table.insert(paths, path) end
        table.sort(paths)
        assert.same({dir .. "/a/nested.md", dir .. "/top.md"}, paths)
        assert.equal(mtimes[dir .. "/top.md"], lfsext.mtime(dir .. "/top.md"))
        os.execute("touch -d '2001-01-01 00:00:00' '" .. dir .. "/top.md'")
        assert.not_equal(mtimes[dir .. "/top.md"], lfsext.mtime(dir .. "/top.md"))
        assert.is_nil(lfsext.mtime(dir .. "/missing.md"))
        os.execute("rm -rf '" .. dir .. "'")
    end)

    describe("globaldir", function()
        local function env(vars)
            return function(name) return vars[name] end
        end

        local function folder(path)
            os.execute("mkdir -p '" .. path .. "'")
            return path
        end

        it("prefers VEX_HOME", function()
            local dir = tmpdir()
            assert.equal(folder(dir .. "/home"), lfsext.globaldir(env {
                VEX_HOME = dir .. "/home", XDG_CONFIG_HOME = dir, HOME = dir,
            }))
            os.execute("rm -rf '" .. dir .. "'")
        end)

        it("falls back to vex inside XDG_CONFIG_HOME", function()
            local dir = tmpdir()
            assert.equal(folder(dir .. "/vex"), lfsext.globaldir(env {XDG_CONFIG_HOME = dir, HOME = dir}))
            os.execute("rm -rf '" .. dir .. "'")
        end)

        it("falls back to ~/.config/vex", function()
            local dir = tmpdir()
            assert.equal(folder(dir .. "/.config/vex"), lfsext.globaldir(env {HOME = dir}))
            os.execute("rm -rf '" .. dir .. "'")
        end)

        it("is nil when the folder does not exist", function()
            local dir = tmpdir()
            assert.is_nil(lfsext.globaldir(env {VEX_HOME = dir .. "/missing"}))
            assert.is_nil(lfsext.globaldir(env {}))
            os.execute("rm -rf '" .. dir .. "'")
        end)
    end)

    describe("globalpath", function()
        it("is a path inside the global folder only when it exists", function()
            local dir = tmpdir()
            os.execute("mkdir -p '" .. dir .. "/tasks'")
            local getenv = function(name) return name == "VEX_HOME" and dir or nil end
            assert.equal(dir .. "/tasks", lfsext.globalpath("tasks", getenv))
            assert.is_falsy(lfsext.globalpath("views", getenv))
            assert.is_falsy(lfsext.globalpath("tasks", function() end))
            os.execute("rm -rf '" .. dir .. "'")
        end)
    end)

    describe("normalise", function()
        it("collapses repeated separators, dot segments and trailing separators", function()
            assert.equal("a/b", lfsext.normalise("a/b/"))
            assert.equal("a/b", lfsext.normalise("./a//b"))
            assert.equal("a/b/c", lfsext.normalise("a/./b/c/."))
        end)

        it("turns backslashes into forward slashes", function()
            assert.equal("a/b", lfsext.normalise("a\\b"))
        end)

        it("names the current folder . when nothing is left", function()
            assert.equal(".", lfsext.normalise(""))
            assert.equal(".", lfsext.normalise("./"))
        end)

        it("keeps an absolute path absolute", function()
            assert.equal("/a/b", lfsext.normalise("//a//b/"))
            assert.equal("/", lfsext.normalise("/"))
        end)
    end)

    describe("isabsolute", function()
        it("tells absolute paths from relative ones", function()
            assert.is_true(lfsext.isabsolute("/a"))
            assert.is_true(lfsext.isabsolute("C:\\a"))
            assert.is_false(lfsext.isabsolute("a/b"))
            assert.is_false(lfsext.isabsolute("."))
        end)
    end)

    describe("layers", function()
        it("lists the global folder, then every .vex above the path from the outermost in", function()
            local dir, home = tmpdir(), tmpdir()
            os.execute("mkdir -p '" .. dir .. "/.vex' '" .. dir .. "/a/.vex' '" .. dir .. "/a/b/c'")
            local getenv = function(name) return name == "VEX_HOME" and home or nil end
            assert.same({home, dir .. "/.vex", dir .. "/a/.vex"}, lfsext.layers(dir .. "/a/b/c", getenv))
            os.execute("rm -rf '" .. dir .. "' '" .. home .. "'")
        end)

        it("leaves out a global folder that does not exist", function()
            local dir = tmpdir()
            os.execute("mkdir -p '" .. dir .. "/.vex'")
            assert.same({dir .. "/.vex"}, lfsext.layers(dir, function() end))
            os.execute("rm -rf '" .. dir .. "'")
        end)
    end)

end)
