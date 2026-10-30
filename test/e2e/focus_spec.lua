local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex, fails = helper.vex, helper.vex_fails

describe("vex focus first and last (e2e, subprocess)", function()
  local dir, ids

  before_each(function()
    dir = helper.project()
    ids = {}
    for i, cost in ipairs({"3", "1", "2", "5", "4"}) do
      ids[i] = vex(dir, "add", "Cost", "task", "number", tostring(i), "--cost", cost)
    end
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function lines(out)
    local list = {}
    for line in out:gmatch("[^\n]+") do table.insert(list, line) end
    return list
  end

  it("keeps the first n tasks of an ordered focus", function()
    vex(dir, "focus", "all", "--orderby", "cost:desc", "--first", "2")
    assert.same({ids[4], ids[5]}, lines(vex(dir, "get", "prev")))
  end)

  it("keeps the last n tasks of an ordered focus in their order", function()
    vex(dir, "focus", "all", "--orderby", "cost:desc", "--last", "2")
    assert.same({ids[3], ids[2]}, lines(vex(dir, "get", "prev")))
  end)

  it("keeps n tasks in each group", function()
    vex(dir, "set", ids[1], "--status", "done")
    vex(dir, "focus", "all", "--groupby", "status", "--first", "1")
    assert.equal(2, #lines(vex(dir, "get", "prev")))
  end)

  it("returns everything when n is larger than the focus", function()
    vex(dir, "focus", "all", "--last", "50")
    assert.equal(5, #lines(vex(dir, "get", "prev")))
  end)

  it("saves the number with the focus, replaying the query", function()
    vex(dir, "focus", "all", "--orderby", "cost", "--first", "1")
    vex(dir, "set", ids[4], "--cost", "0")
    assert.same({ids[4]}, lines(vex(dir, "get", "prev")))
  end)

  it("rejects an n that is not a whole number above zero", function()
    for _, n in ipairs({"0", "-1", "many"}) do
      fails(dir, "whole number above zero", "focus", "all", "--first", n)
      fails(dir, "whole number above zero", "focus", "all", "--last", n)
    end
  end)
end)

describe("vex get separators and feeding a focus into a list field (e2e, subprocess)", function()
  local dir, atoms, final

  before_each(function()
    dir = helper.project()
    atoms = {}
    local parent = vex(dir, "add", "Parent", "abstract", "--vextype", "abstract")
    for i = 1, 3 do
      atoms[i] = vex(dir, "add", "Child", "atom", tostring(i), "--vextype", "atom")
    end
    vex(dir, "set", parent, "--children", table.concat(atoms, ","))
    final = vex(dir, "add", "Final", "atom", "--vextype", "atom")
    vex(dir, "focus", parent, "--tree", "children", "--filter", "vextype:atom")
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  it("puts a focus's vexids in one line when given a comma", function()
    assert.equal(table.concat(atoms, ","), vex(dir, "get", "prev", ","))
  end)

  it("sets a list field from the saved focus through shell substitution", function()
    helper.shell(dir, "vex set " .. final .. " --dependencies $(vex get prev ,)")
    local got = vex(dir, "get", final, "--dependencies")
    for _, vexid in ipairs(atoms) do assert.truthy(got:find(vexid, 1, true)) end
  end)

  it("keeps the other values when inserting from the saved focus", function()
    local extra = vex(dir, "add", "Extra", "atom", "--vextype", "atom")
    vex(dir, "set", final, "--dependencies", extra)
    vex(dir, "focus", atoms[1] .. "," .. atoms[2] .. "," .. atoms[3])
    vex(dir, "set", final, "--insert", "--dependencies", (vex(dir, "get", "prev", ",")))
    local got = vex(dir, "get", final, "--dependencies")
    for _, vexid in ipairs({extra, atoms[1], atoms[2], atoms[3]}) do
      assert.truthy(got:find(vexid, 1, true))
    end
  end)

  it("separates rows and columns as asked", function()
    local out = vex(dir, "get", "prev", ";", "|", "--vexid", "--cost")
    assert.equal(atoms[1] .. "|;" .. atoms[2] .. "|;" .. atoms[3] .. "|", out)
  end)

  it("joins the vexids with nothing when emptied", function()
    assert.equal(table.concat(atoms), vex(dir, "get", "prev", ""))
  end)
end)
