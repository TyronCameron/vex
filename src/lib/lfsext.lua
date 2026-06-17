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