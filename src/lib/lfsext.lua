local lfs = require 'lib.lfs'

local lfsext = {}

function lfsext.rootdir(path)
    local current = path
    while current do
        if lfs.attributes(current .. "/.vex", "mode") == "directory" then
            return current
        end
        local parent = current:match("(.+)[\\/][^\\/]+$")
        if parent == current then
            break
        end
        current = parent
    end
    return nil
end

function lfsext.globaldir(getenv)
    getenv = getenv or os.getenv
    local function under(variable, suffix)
        local base = getenv(variable)
        return base and base .. suffix
    end
    local candidates = {
        getenv('VEX_HOME') or false,
        under('APPDATA', '\\vex') or false,
        under('XDG_CONFIG_HOME', '/vex') or false,
        under('HOME', '/.config/vex') or false,
    }
    for _, path in ipairs(candidates) do
        if path and lfs.attributes(path, 'mode') == 'directory' then return path end
    end
    return nil
end

function lfsext.globalpath(name, getenv)
    local dir = lfsext.globaldir(getenv)
    local path = dir and dir .. '/' .. name
    return path and lfs.attributes(path, 'mode') and path
end

function lfsext.walk(path, files)
    files = files or {}
    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local full = path .. "/" .. file
            if lfs.attributes(full, "mode") == "directory" then
                lfsext.walk(full, files)
            else
                table.insert(files, full)
            end
        end
    end
    return files
end

return lfsext