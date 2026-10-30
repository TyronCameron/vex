local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

describe("vex view with focus flags (e2e, subprocess)", function()
  local dir, milk, eggs, bread

  before_each(function()
    dir = helper.project()
    milk = vex(dir, "add", "Buy", "milk")
    eggs = vex(dir, "add", "Buy", "eggs")
    bread = vex(dir, "add", "Buy", "bread")
    vex(dir, "set", eggs, "--status", "done")
    vex(dir, "focus", milk)
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function plain(out)
    return (out:gsub("\27%[[0-9;]*m", ""))
  end

  it("filters and selects through the focus flags it is given", function()
    local out = vex(dir, "view", "all", "tabular", "--filter", "status:done", "--select", "status")
    assert.truthy(out:find(eggs, 1, true), out)
    assert.is_nil(out:find(milk, 1, true), out)
    assert.is_nil(out:find("description", 1, true), out)
  end)

  it("orders the rows by the focus flags it is given", function()
    local out = vex(dir, "view", "all", "tabular", "--orderby", "vexid:desc")
    assert.truthy(out:find(milk, 1, true) < out:find(eggs, 1, true), out)
    assert.truthy(out:find(eggs, 1, true) < out:find(bread, 1, true), out)
  end)

  it("shows a subheader per group, with each group's rows under it", function()
    local out = plain(vex(dir, "view", "all", "tabular", "--groupby", "status", "--orderby", "vexid:desc", "--select", "status"))
    local done, todo = out:find("│ status: done", 1, true), out:find("│ status: todo", 1, true)
    assert.truthy(done and todo, out)
    assert.truthy(done < out:find("│ │ " .. eggs, 1, true), out)
    assert.truthy(todo < out:find("│ │ " .. milk, 1, true), out)
    assert.truthy(out:find(milk, 1, true) < out:find(bread, 1, true), out)
  end)

  it("shows a selected path", function()
    local out = vex(dir, "view", "all", "tabular", "--filter", "vexid:" .. milk, "--select", "path")
    assert.truthy(out:find(milk .. ".md", 1, true), out)
  end)

  it("keeps a subheader per group when the grouped field isn't selected", function()
    local out = plain(vex(dir, "view", "all", "tabular", "--groupby", "status", "--select", "description"))
    assert.truthy(out:find("│ status: done", 1, true), out)
    assert.truthy(out:find("│ status: todo", 1, true), out)
  end)

  it("shows the groups of a saved grouped focus", function()
    vex(dir, "focus", "all", "--groupby", "status")
    assert.truthy(plain(vex(dir, "view", "tabular")):find("│ status: done", 1, true))
  end)

  it("applies the flags to the saved focus without saving over it", function()
    local out = vex(dir, "view", "tabular", "--select", "status")
    assert.truthy(out:find(milk, 1, true), out)
    assert.is_nil(out:find(eggs, 1, true), out)
    vex(dir, "view", "all", "tabular", "--filter", "status:done")
    assert.truthy(vex(dir, "focus"):find("1", 1, true))
    assert.truthy(vex(dir, "view", "csv"):find(milk, 1, true))
    assert.is_nil(vex(dir, "view", "csv"):find(eggs, 1, true))
  end)

  it("keeps the order of its focus flags, numbering within groups", function()
    local out = vex(dir, "view", "all", "tabular", "--groupby", "status", "--orderby", "vexid", "--rn", "--select", "rn")
    local rows = {}
    for vexid, rn in plain(out):gmatch("([%w%-]+%-1)%s*│%s*(%d+)") do rows[vexid] = rn end
    assert.same({[eggs] = "1", [bread] = "1", [milk] = "2"}, rows)
  end)

  it("rejects a tabular flag that is not a focus operation", function()
    helper.vex_fails(dir, "Unknown focus operation `bogus`", "view", "all", "tabular", "--bogus", "x")
  end)

  it("leaves other views to their own flags", function()
    local out = vex(dir, "view", "all", "csv", "--filter", "status:done")
    assert.truthy(out:find(milk, 1, true), out)
  end)

  it("puts the initial status first in the kanban view, then the rest by moves from it", function()
    local out = plain(vex(dir, "view", "all", "kanban"))
    assert.truthy(out:find("todo", 1, true) < out:find("done", 1, true), out)
  end)

  it("still passes a view its own flags", function()
    local out = vex(dir, "view", "all", "kanban", "--field", "vextype")
    assert.truthy(out:find("task", 1, true), out)
    assert.is_nil(out:find("done", 1, true), out)
  end)
end)
