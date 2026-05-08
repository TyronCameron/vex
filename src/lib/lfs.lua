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
        local cmd = string.format(
            'powershell -NoProfile -Command ' ..
            '"$i=Get-Item \'%s\' -ErrorAction SilentlyContinue;' ..
            'if($i){$i.PSIsContainer;' ..
            'if($i.PSIsContainer){0}else{$i.Length};' ..
            '$i.LastWriteTimeUtc.ToFileTimeUtc()}"',
            path
        )
        local out = shell(cmd)
        if out == "" then return nil end

        local lines = {}
        for line in (out .. "\n"):gmatch("([^\r\n]*)\r?\n") do
            lines[#lines + 1] = line
        end

        info.mode         = (lines[1] == "True") and "directory" or "file"
        info.size         = tonumber(lines[2]) or 0
        local ft          = tonumber(lines[3]) or 0
        info.modification = math.floor((ft - 116444736000000000) / 10000000)
        info.access       = info.modification
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