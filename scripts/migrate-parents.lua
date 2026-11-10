-- Moves a project's hierarchy from each parent's `children`/`options` lists to a `parent` field on each child.
-- Run once from the project root, then `vex resolve all --force`: luajit scripts/migrate-parents.lua <taskfolder>
local scripts = debug.getinfo(1, "S").source:match("^@(.-)[^\\/]*$")
package.path = (scripts ~= "" and scripts or "./") .. "../src/?.lua;" .. package.path
local obsidian = require 'default.obsidian'

local folder = arg[1]
if not folder then
    io.stderr:write("usage: luajit scripts/migrate-parents.lua <taskfolder>\n")
    os.exit(2)
end

local function files()
    local handle = assert(io.popen("find '" .. folder:gsub("'", "'\\''") .. "' -name '*.md' -not -path '*/.*'"))
    local paths = {}
    for path in handle:lines() do table.insert(paths, path) end
    handle:close()
    table.sort(paths)
    return paths
end

local function unlink(value)
    return value:match("%[%[(.-)%]%]") or value
end

local function slurp(path)
    local f = assert(io.open(path, "r"))
    local content = f:read("*a")
    f:close()
    return content
end

local tasks, paths = {}, {}
for _, path in ipairs(files()) do
    local ok, task = pcall(obsidian.parse, slurp(path))
    if ok and task and task.vexid then
        tasks[task.vexid], paths[task.vexid] = task, path
    end
end

local parentof, held, problems = {}, {}, {}
for vexid, task in pairs(tasks) do
    for _, field in ipairs({'children', 'options'}) do
        if task[field] ~= nil then held[vexid] = true end
        for _, link in ipairs(type(task[field]) == "table" and task[field] or {task[field]}) do
            local child = unlink(link)
            if not tasks[child] then
                table.insert(problems, vexid .. " lists " .. child .. ", which has no task file")
            elseif parentof[child] and parentof[child] ~= vexid then
                table.insert(problems, child .. " is listed by both " .. parentof[child] .. " and " .. vexid)
            elseif tasks[child].parent and unlink(tasks[child].parent) ~= vexid then
                table.insert(problems, child .. " already has the parent " .. unlink(tasks[child].parent) .. " but is listed by " .. vexid)
            else
                parentof[child] = vexid
            end
        end
    end
end

if #problems > 0 then
    table.sort(problems)
    io.stderr:write("Nothing was changed:\n  " .. table.concat(problems, "\n  ") .. "\n")
    os.exit(1)
end

local function migrate(content, vexid)
    local frontmatter, rest = content:match("^%-%-%-\n(.-\n)(%-%-%-\n.*)$")
    local lines, skipping = {}, false
    for line in frontmatter:gmatch("([^\n]*)\n") do
        local key = line:match("^([%w_]+):")
        if key then skipping = held[vexid] and (key == 'children' or key == 'options') end
        if not skipping then table.insert(lines, line) end
    end
    if parentof[vexid] and not tasks[vexid].parent then
        table.insert(lines, 'parent: "[[' .. parentof[vexid] .. ']]"')
    end
    return "---\n" .. table.concat(lines, "\n") .. "\n" .. rest
end

local emptied, parented = 0, 0
for vexid, path in pairs(paths) do
    if held[vexid] or (parentof[vexid] and not tasks[vexid].parent) then
        local content = migrate(slurp(path), vexid)
        local f = assert(io.open(path, "w"))
        f:write(content)
        f:close()
        if held[vexid] then emptied = emptied + 1 end
        if parentof[vexid] and not tasks[vexid].parent then parented = parented + 1 end
    end
end

print(string.format("Moved the lists of %d tasks onto the parent field of %d tasks. Now run `vex resolve all --force`.", emptied, parented))
