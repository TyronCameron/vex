-- src/lib/lfs.lua
local lfs = {}

local is_windows = package.config:sub(1,1) == "\\"

local function shell(cmd)
    local p = io.popen(cmd)
    local result = p:read("*a"):gsub("%s+$", "")
    p:close()
    return result
end

function lfs.currentdir()
    return shell(is_windows and "cd" or "pwd")
end

function lfs.chdir(path)
    -- can't actually chdir in-process via popen, but we can track it
    -- this is a known limitation of the shim
    os.execute((is_windows and "cd /d " or "cd ") .. path)
end

function lfs.mkdir(path)
    local cmd = is_windows and ('mkdir "' .. path .. '"') or ('mkdir -p "' .. path .. '"')
    return os.execute(cmd)
end

function lfs.rmdir(path)
    local cmd = is_windows and ('rmdir /s /q "' .. path .. '"') or ('rm -rf "' .. path .. '"')
    return os.execute(cmd)
end

function lfs.attributes(path, attr)
    local info = {}
    if is_windows then
        local out = shell('powershell -Command "Get-Item \'' .. path .. '\' | Select-Object -Property Mode,Length,LastWriteTime | ConvertTo-Csv -NoTypeInformation" 2>nul')
        if out == "" then return nil end
        -- rough parse: just enough to answer mode/size/modification
        info.mode   = out:match("^d") and "directory" or "file"
        info.size   = tonumber(out:match(",(%d+),")) or 0
    else
        local out = shell('stat "' .. path .. '" 2>/dev/null')
        if out == "" then return nil end
        info.mode   = out:match("directory") and "directory" or "file"
        info.size   = tonumber(out:match("Size:%s*(%d+)")) or 0
    end
    if attr then return info[attr] end
    return info
end

function lfs.dir(path)
    local entries = {}
    local cmd = is_windows and ('dir /b "' .. path .. '"') or ('ls -1a "' .. path .. '"')
    local out = shell(cmd)
    for entry in out:gmatch("[^\r\n]+") do
        table.insert(entries, entry)
    end
    -- add . and .. to match real lfs behaviour
    table.insert(entries, 1, "..")
    table.insert(entries, 1, ".")
    local i = 0
    return function()
        i = i + 1
        return entries[i]
    end
end

return lfs