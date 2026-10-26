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

end)
