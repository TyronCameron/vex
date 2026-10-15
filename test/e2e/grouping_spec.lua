local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'

describe("vex grouped task paths (e2e, subprocess)", function()
  local dir

  local function groupby(fields)
    local f = assert(io.open(dir .. "/.vex/config.lua", "w"))
    f:write("return { taskfolder = '.', groupby = { '" .. table.concat(fields, "', '") .. "' } }")
    f:close()
  end

  local function add(...)
    return helper.trim(helper.run_vex(dir, {"add", ...}).stdout)
  end

  local function link(path, targets)
    local items = {"children:"}
    for _, target in ipairs(targets) do
      table.insert(items, '  - "[[' .. target .. ']]"')
    end
    local content = helper.read_file(dir .. "/" .. path)
      :gsub("\nchildren: %[%]\n", "\n" .. table.concat(items, "\n") .. "\n", 1)
    local f = assert(io.open(dir .. "/" .. path, "w"))
    f:write(content)
    f:close()
  end

  local function exists(path)
    return helper.is_file(dir .. "/" .. path)
  end

  before_each(function()
    dir = helper.make_tmp_dir()
    helper.run_vex(dir, {"init"})
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  it("keeps files flat without groupby", function()
    local task = add("Flat", "little", "task")
    assert.is_true(exists(task .. ".md"))
  end)

  it("nests children under their parent chain", function()
    groupby {"parent"}
    local top = add("Top", "level", "abstract", "--vextype", "abstract")
    local middle = add("Middle", "level", "abstract", "--vextype", "abstract")
    local leaf = add("Leaf", "level", "task")
    link(top .. ".md", {middle})
    link(middle .. ".md", {leaf})
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)

    assert.is_true(exists(top .. ".md"))
    assert.is_true(exists(top .. "/" .. middle .. ".md"))
    assert.is_true(exists(top .. "/" .. middle .. "/" .. leaf .. ".md"))
    assert.is_false(exists(middle .. ".md"))
    assert.is_false(exists(leaf .. ".md"))
  end)

  it("finds moved files on later runs", function()
    groupby {"parent"}
    local top = add("Top", "level", "abstract", "--vextype", "abstract")
    local leaf = add("Leaf", "level", "task")
    link(top .. ".md", {leaf})
    helper.run_vex(dir, {"resolve", "all"})

    local res = helper.run_vex(dir, {"set", leaf, "--status", "doing"})
    assert.are.equal(0, res.code, res.stderr)
    assert.truthy(helper.read_file(dir .. "/" .. top .. "/" .. leaf .. ".md"):find("status: doing", 1, true))
    assert.truthy(helper.strip_ansi(helper.run_vex(dir, {"show", leaf}).stdout):find("doing", 1, true))
  end)

  it("moves a subtree back up when its parent is removed", function()
    groupby {"parent"}
    local top = add("Top", "level", "abstract", "--vextype", "abstract")
    local middle = add("Middle", "level", "abstract", "--vextype", "abstract")
    local leaf = add("Leaf", "level", "task")
    link(top .. ".md", {middle})
    link(middle .. ".md", {leaf})
    helper.run_vex(dir, {"resolve", "all"})

    local res = helper.run_vex(dir, {"remove", top})
    assert.are.equal(0, res.code, res.stderr)

    assert.is_true(exists(middle .. ".md"))
    assert.is_true(exists(middle .. "/" .. leaf .. ".md"))
    assert.is_false(helper.is_dir(dir .. "/" .. top))
  end)

  it("moves a file between status folders when its status changes", function()
    groupby {"status"}
    local task = add("Status", "grouped", "task")
    assert.is_true(exists("todo/" .. task .. ".md"))

    assert.are.equal(0, helper.run_vex(dir, {"set", task, "--status", "doing"}).code)

    assert.is_true(exists("doing/" .. task .. ".md"))
    assert.is_false(helper.is_dir(dir .. "/todo"))
  end)

  it("nests groups in the order given", function()
    groupby {"parent", "status"}
    local top = add("Top", "level", "abstract", "--vextype", "abstract")
    local leaf = add("Leaf", "level", "task")
    link("todo/" .. top .. ".md", {leaf})
    helper.run_vex(dir, {"resolve", "all"})

    assert.is_true(exists("todo/" .. top .. ".md"))
    assert.is_true(exists(top .. "/todo/" .. leaf .. ".md"))
  end)

  it("finds a file that was moved by hand", function()
    local task = add("Dragged", "by", "hand")
    os.execute("mkdir " .. helper.shell_escape(dir .. "/elsewhere") .. " && mv " .. helper.shell_escape(dir .. "/" .. task .. ".md") .. " " .. helper.shell_escape(dir .. "/elsewhere/"))

    local res = helper.run_vex(dir, {"show", task})
    assert.are.equal(0, res.code, res.stderr)
    assert.truthy(helper.strip_ansi(res.stdout):find(task, 1, true))
    assert.are.equal(0, helper.run_vex(dir, {"set", task, "--status", "doing"}).code)
  end)

  it("finds files with no recorded path once groupby is switched on", function()
    local task = add("Recorded", "before", "grouping")
    os.remove(dir .. "/.vex/vexdex/paths.bin")
    groupby {"status"}

    local res = helper.run_vex(dir, {"show", task})
    assert.are.equal(0, res.code, res.stderr)
    assert.truthy(helper.strip_ansi(res.stdout):find(task, 1, true))
  end)

  it("focuses on the tasks in a folder or file", function()
    groupby {"status"}
    local first = add("First", "todo", "task")
    add("Second", "todo", "task")

    assert.truthy(helper.strip_ansi(helper.run_vex(dir, {"focus", "todo/"}).stdout):find("Focusing on 2 vexes", 1, true))
    assert.truthy(helper.strip_ansi(helper.run_vex(dir, {"focus", "todo/" .. first .. ".md"}).stdout):find("Focusing on 1 vex", 1, true))
  end)
end)
