local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'

describe("vex linking (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.project()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function add(...)
    return helper.trim(helper.run_vex(dir, {"add", ...}).stdout)
  end

  local function link(vexid, field, targets)
    helper.link(dir, vexid, field, targets)
  end

  local function under(out, heading, vexid)
    return out:find(heading .. "%s+" .. (vexid:gsub("%-", "%%-")))
  end

  it("vex remove strips the removed task from other tasks' parent and dependencies", function()
    local parent = add("Removable", "parent", "--vextype", "abstract")
    local child = add("Orphaned", "child", "task")
    local needed = add("Removable", "needed", "task")
    local dependent = add("Dependent", "atom", "task")
    link(child, "parent", parent)
    link(dependent, "dependencies", {needed})
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)

    assert.are.equal(0, helper.run_vex(dir, {"remove", parent .. "," .. needed}).code)

    assert.is_nil(helper.read_file(dir .. "/" .. child .. ".md"):find(parent, 1, true))
    assert.is_nil(helper.read_file(dir .. "/" .. dependent .. ".md"):find(needed, 1, true))
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)
  end)

  it("vex view singular shows the parent chain, children and dependencies both ways", function()
    local top = add("Top", "level", "abstract", "--vextype", "abstract")
    local middle = add("Middle", "level", "abstract", "--vextype", "abstract")
    local task = add("Focused", "atom", "task")
    local before = add("Needed", "before", "task")
    local after = add("Needed", "after", "task")
    link(middle, "parent", top)
    link(task, "parent", middle)
    link(task, "dependencies", {before})
    link(after, "dependencies", {task})
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)

    local result = helper.run_vex(dir, {"view", task, "singular"})
    assert.are.equal(0, result.code)
    local out = helper.strip_ansi(result.stdout)
    local top_at = out:find(top, 1, true)
    local middle_at = out:find(middle, 1, true)
    assert.is_not_nil(top_at)
    assert.is_not_nil(middle_at)
    assert.is_true(top_at < middle_at)
    assert.is_not_nil(under(out, "DEPENDS ON", before))
    assert.is_not_nil(under(out, "DEPENDED ON BY", after))

    local parent_out = helper.strip_ansi(helper.run_vex(dir, {"view", middle, "singular"}).stdout)
    assert.is_not_nil(under(parent_out, "CHILDREN", task))
  end)

  local function focused(...)
    local out = helper.vex(dir, "focus", ...)
    local ids = {}
    for id in helper.vex(dir, "get"):gmatch("[^\n]+") do table.insert(ids, helper.trim(id)) end
    table.sort(ids)
    return ids, out
  end

  it("--step moves one hop along children, parent, forwardlinks or backlinks", function()
    local top = add("Top", "level", "abstract", "--vextype", "abstract")
    local middle = add("Middle", "level", "abstract", "--vextype", "abstract", "--parent", top)
    local leaf = add("Leaf", "level", "task", "--parent", middle)

    assert.same({middle}, (focused(top, "--step", "children")))
    assert.same({leaf}, (focused(top, "--step", "children", "--step", "children")))
    assert.same({middle}, (focused(leaf, "--step", "parent")))
    assert.same({middle}, (focused(leaf, "--step", "forwardlinks")))
    assert.same({middle}, (focused(top, "--step", "backlinks")))
    assert.same({top}, (focused(leaf, "--step", "forwardlinks", "--step", "forwardlinks")))
  end)

  it("--tree cascades through forwardlinks, backlinks, children or parent", function()
    local top = add("Top", "level", "abstract", "--vextype", "abstract")
    local middle = add("Middle", "level", "abstract", "--vextype", "abstract")
    local leaf = add("Leaf", "level", "task")
    link(middle, "parent", top)
    link(leaf, "parent", middle)
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)

    local expected = {top, middle, leaf}
    table.sort(expected)
    assert.same(expected, (focused(leaf, "--tree", "forwardlinks")))
    assert.same(expected, (focused(top, "--tree", "backlinks")))
    assert.same(expected, (focused(top, "--tree", "children")))
    assert.same(expected, (focused(leaf, "--tree", "parent")))
  end)

  it("vex get shows backlinks and forwardlinks as fields", function()
    local parent = add("Parent", "abstract", "task", "--vextype", "abstract")
    local child = add("Linked", "child", "task")
    link(child, "parent", parent)
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)

    assert.are.equal(child, helper.trim(helper.vex(dir, "get", parent, "--backlinks")))
    assert.are.equal(parent, helper.trim(helper.vex(dir, "get", child, "--forwardlinks")))
  end)
end)
