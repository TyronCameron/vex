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

local is_windows = package.config:sub(1,1) == "\\"

local function quote(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
end

local gnu
local function isgnu()
    if gnu == nil then
        local status = os.execute("find --version >/dev/null 2>&1")
        gnu = status == 0 or status == true
    end
    return gnu
end

local function listmtimes(command)
    local mtimes = {}
    local p = io.popen(command)
    for line in p:lines() do
        local mtime, path = line:match("^([^\t]+)\t(.+)$")
        if mtime then mtimes[(path:gsub("\\", "/"))] = mtime end
    end
    p:close()
    return mtimes
end

local function findmtimes(path, depth)
    if is_windows then
        return listmtimes('powershell -NoProfile -Command "' ..
            (depth and "Get-Item '" .. path .. "'" or "Get-ChildItem '" .. path .. "' -Recurse -File | Where-Object { $_.FullName -notmatch '[\\\\/]\\.' }") ..
            ' | ForEach-Object { \"$($_.LastWriteTimeUtc.Ticks)`t$($_.FullName)\" }"')
    end
    local select = depth and " -maxdepth 0 -type f" or " -mindepth 1 -name '.*' -prune -o -type f"
    local action = isgnu() and " -printf '%T@\\t%p\\n'" or " -exec stat -f '%Fm%t%N' {} +"
    return listmtimes("find " .. quote(path) .. select .. action .. " 2>/dev/null")
end

-- the modification time of every file below a folder, hidden ones aside, by path
function lfsext.mtimes(path)
    return findmtimes(path)
end

function lfsext.mtime(path)
    return findmtimes(path, true)[path]
end

return lfsext