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

  it("vex remove strips the removed task from other tasks' children and dependencies", function()
    local child = add("Removable", "child", "task")
    local parent = add("Parent", "abstract", "task", "--vextype", "abstract")
    local dependent = add("Dependent", "atom", "task")
    link(parent, "children", {child})
    link(dependent, "dependencies", {child})
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)

    assert.are.equal(0, helper.run_vex(dir, {"remove", child}).code)

    assert.is_nil(helper.read_file(dir .. "/" .. parent .. ".md"):find(child, 1, true))
    assert.is_nil(helper.read_file(dir .. "/" .. dependent .. ".md"):find(child, 1, true))
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)
  end)

  it("vex view singular shows the parent chain, children and dependencies both ways", function()
    local top = add("Top", "level", "abstract", "--vextype", "abstract")
    local middle = add("Middle", "level", "abstract", "--vextype", "abstract")
    local task = add("Focused", "atom", "task")
    local before = add("Needed", "before", "task")
    local after = add("Needed", "after", "task")
    link(top, "children", {middle})
    link(middle, "children", {task})
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
end)
