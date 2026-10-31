local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

describe("vex grouped task paths (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.project()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function groupby(fields)
    local config = dir .. "/.vex/config.lua"
    helper.write_file(config, helper.read_file(config):gsub("^return {", "return {\n  paths = { groupby = " .. fields .. " },"))
  end

  local function exists(path)
    return helper.is_file(dir .. "/" .. path)
  end

  local function unlink(vexid, field)
    local path = helper.task_file(dir, vexid)
    helper.write_file(path, helper.read_file(path):gsub("\n" .. field .. ": ?\n[^\n]*\n", "\n" .. field .. ": []\n"))
  end

  local function family()
    local top = vex(dir, "add", "Top", "level", "abstract", "--vextype", "abstract")
    local middle = vex(dir, "add", "Middle", "level", "abstract", "--vextype", "abstract")
    local leaf = vex(dir, "add", "Leaf", "level", "task")
    helper.link(dir, top, "children", {middle})
    helper.link(dir, middle, "children", {leaf})
    vex(dir, "resolve", "all")
    return top, middle, leaf
  end

  it("keeps task files flat without groupby", function()
    local vexid = vex(dir, "add", "Flat", "little", "task")
    assert.is_true(exists(vexid .. ".md"))
  end)

  it("nests tasks by status and lineage in a freshly initialised project", function()
    local fresh = helper.make_tmp_dir()
    helper.run_vex(fresh, {"init"})
    local parent = vex(fresh, "add", "Fresh", "parent", "abstract", "--vextype", "abstract")
    local child = vex(fresh, "add", "Fresh", "child", "task")
    helper.link(fresh, parent, "children", {child})
    vex(fresh, "resolve", "all")
    assert.is_true(helper.is_file(fresh .. "/todo/" .. parent .. ".md"))
    assert.is_true(helper.is_file(fresh .. "/todo/" .. parent .. "/" .. child .. ".md"))
    helper.rm_tmp_dir(fresh)
  end)

  it("nests tasks in folders by lineage", function()
    groupby "{'lineage'}"
    local top, middle, leaf = family()
    assert.is_true(exists(top .. ".md"))
    assert.is_true(exists(top .. "/" .. middle .. ".md"))
    assert.is_true(exists(top .. "/" .. middle .. "/" .. leaf .. ".md"))
  end)

  it("moves an abstract between status folders as its children progress", function()
    groupby "{'status'}"
    local parent = vex(dir, "add", "Status", "parent", "--vextype", "abstract")
    local child = vex(dir, "add", "Status", "child", "task")
    local sibling = vex(dir, "add", "Status", "sibling", "task")
    vex(dir, "set", parent, "--insert", "--children", child .. "," .. sibling)
    assert.is_true(exists("todo/" .. parent .. ".md"))
    vex(dir, "set", child, "--status", "done")
    assert.is_true(exists("doing/" .. parent .. ".md"))
    assert.is_false(exists("todo/" .. parent .. ".md"))
    vex(dir, "set", sibling, "--status", "done")
    assert.is_true(exists("done/" .. parent .. ".md"))
  end)

  it("moves a task and everything below it out when it is unlinked", function()
    groupby "{'lineage'}"
    local top, middle, leaf = family()
    unlink(top, "children")
    vex(dir, "resolve", top)
    assert.is_true(exists(middle .. ".md"))
    assert.is_true(exists(middle .. "/" .. leaf .. ".md"))
    assert.is_false(helper.is_dir(dir .. "/" .. top))
  end)

  it("moves the tasks below a removed task up and drops its folder", function()
    groupby "{'lineage'}"
    local top, middle, leaf = family()
    vex(dir, "remove", top)
    assert.is_true(exists(middle .. ".md"))
    assert.is_true(exists(middle .. "/" .. leaf .. ".md"))
    assert.is_false(helper.is_dir(dir .. "/" .. top))
  end)

  it("moves a dependent between folders as the tasks it depends on finish", function()
    groupby "{'blockers'}"
    local first = vex(dir, "add", "Blocking", "first", "task")
    local second = vex(dir, "add", "Blocking", "second", "task")
    local dependent = vex(dir, "add", "Dependent", "task", "--dependencies", first .. "," .. second)
    assert.is_true(exists(first .. "/" .. second .. "/" .. dependent .. ".md"))
    vex(dir, "set", first, "--status", "done")
    assert.is_true(exists(second .. "/" .. dependent .. ".md"))
    vex(dir, "set", second, "--status", "done")
    assert.is_true(exists(dependent .. ".md"))
    assert.is_false(helper.is_dir(dir .. "/" .. second))
  end)

  it("moves a whole subtree when its root is reparented", function()
    groupby "{'lineage'}"
    local top, middle, leaf = family()
    local other = vex(dir, "add", "Other", "root", "abstract", "--vextype", "abstract")
    vex(dir, "set", top, "--remove", "--children", middle)
    vex(dir, "set", other, "--insert", "--children", middle)
    assert.is_true(exists(other .. "/" .. middle .. ".md"))
    assert.is_true(exists(other .. "/" .. middle .. "/" .. leaf .. ".md"))
    assert.is_false(helper.is_dir(dir .. "/" .. top))
  end)

  it("settles a link cycle without looping", function()
    groupby "{'lineage'}"
    local first = vex(dir, "add", "Cycle", "first", "--vextype", "abstract")
    local second = vex(dir, "add", "Cycle", "second", "--vextype", "abstract")
    helper.link(dir, first, "children", {second})
    helper.link(dir, second, "children", {first})
    local result = helper.run_vex(dir, {"resolve", "all"})
    assert.is_nil(result.stderr:find("Internal error", 1, true), result.stderr)
  end)

  it("moves a task between folders when the grouped field changes", function()
    groupby "{'status'}"
    local vexid = vex(dir, "add", "Status", "grouped", "task")
    assert.is_true(exists("todo/" .. vexid .. ".md"))
    vex(dir, "set", vexid, "--status", "done")
    assert.is_true(exists("done/" .. vexid .. ".md"))
    assert.is_false(helper.is_dir(dir .. "/todo"))
  end)

  it("nests the groups in the order given", function()
    groupby "{'lineage', 'status'}"
    local top, middle, leaf = family()
    assert.is_true(exists("todo/" .. top .. ".md"))
    assert.is_true(exists(top .. "/todo/" .. middle .. ".md"))
    assert.is_true(exists(top .. "/" .. middle .. "/todo/" .. leaf .. ".md"))
  end)

  it("keeps a value with a slash in a single folder", function()
    groupby "{'description'}"
    local vexid = vex(dir, "add", "Run", "an", "A/B", "test")
    assert.is_true(exists("Run an A-B test/" .. vexid .. ".md"))
  end)

  it("finds a task file moved by hand and puts it back", function()
    groupby "{'status'}"
    local vexid = vex(dir, "add", "Dragged", "by", "hand")
    os.execute("mkdir " .. helper.shell_escape(dir .. "/elsewhere") .. " && mv " .. helper.shell_escape(dir .. "/todo/" .. vexid .. ".md") .. " " .. helper.shell_escape(dir .. "/elsewhere/"))
    assert.truthy(vex(dir, "show", vexid):find(vexid, 1, true))
    vex(dir, "set", vexid, "--status", "done")
    assert.is_true(exists("done/" .. vexid .. ".md"))
    assert.is_false(exists("elsewhere/" .. vexid .. ".md"))
  end)

  it("finds task files written before groupby was switched on", function()
    local vexid = vex(dir, "add", "Written", "while", "flat")
    os.remove(dir .. "/.vex/vexdex/paths.bin")
    groupby "{'status'}"
    assert.truthy(vex(dir, "show", vexid):find(vexid, 1, true))
    vex(dir, "resolve", "all")
    assert.is_true(exists("todo/" .. vexid .. ".md"))
  end)

  it("rearranges files after a groupby change only when resolving with --force", function()
    local vexid = vex(dir, "add", "Regrouped", "later", "task")
    groupby "{'status'}"
    vex(dir, "resolve", "all")
    assert.is_true(exists(vexid .. ".md"))
    vex(dir, "resolve", "all", "--force")
    assert.is_true(exists("todo/" .. vexid .. ".md"))
  end)

  it("focuses on the tasks in a grouped folder", function()
    groupby "{'status'}"
    vex(dir, "add", "First", "todo", "task")
    vex(dir, "add", "Second", "todo", "task")
    assert.truthy(vex(dir, "focus", "todo/"):find("Focusing on 2 vexes", 1, true))
  end)

  it("rejects a groupby that is not a list of field names", function()
    groupby "'status'"
    helper.vex_fails(dir, "groupby", "add", "Badly", "grouped", "task")
  end)
end)
