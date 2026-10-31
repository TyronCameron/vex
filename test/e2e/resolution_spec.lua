local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

local AUDIT = "(double-check-cascading-resolving-1)"

describe("vex resolution never loses or skips data (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.project()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function path(vexid)
    return dir .. "/" .. vexid .. ".md"
  end

  local function edit(vexid, from, to)
    helper.write_file(path(vexid), (helper.read_file(path(vexid)):gsub(from, to, 1)))
  end

  local function count(...)
    return tonumber(vex(dir, "focus", "all", ...):match("Focusing on (%d+)"))
  end

  it("ignores a task file it cannot read and resolves the rest", function()
    local keep = vex(dir, "add", "Keep", "this", "task")
    local broken = vex(dir, "add", "Truncated", "task", "file")
    local content = helper.read_file(path(broken))
    helper.write_file(path(broken), content:match("^(.-\ncreated:[^\n]*\n)"))
    vex(dir, "resolve", "all")
    assert.equal(1, count())
    assert.truthy(vex(dir, "show", keep):find("Keep this task", 1, true))
  end)

  it("fails on two files holding the same vexid " .. AUDIT, function()
    local vexid = vex(dir, "add", "Duplicated", "task", "here")
    os.execute("mkdir -p " .. helper.shell_escape(dir .. "/copy"))
    helper.write_file(dir .. "/copy/" .. vexid .. ".md", helper.read_file(path(vexid)))
    local result = helper.run_vex(dir, {"resolve", "all"})
    assert.is_true(result.code ~= 0, "resolve all accepted two files for " .. vexid)
  end)

  it("resolves a hand-edited task before reading it", function()
    local vexid = vex(dir, "add", "Edited", "by", "hand")
    edit(vexid, "\nstatus: todo\n", "\nstatus: todo\ncost: 9\n")
    assert.equal("9", vex(dir, "get", vexid, "--cost"))
    assert.equal(1, count("--filter", "cost:9"))
  end)

  it("refuses to read a hand edit that does not resolve", function()
    local vexid = vex(dir, "add", "Edited", "badly", "here")
    edit(vexid, "\nstatus: todo\n", "\nstatus: todo\ncost: lots\n")
    helper.vex_fails(dir, "validation step failed", "get", vexid, "--cost")
  end)

  it("changes neither the file nor the index when a linked task fails to resolve " .. AUDIT, function()
    local parent = vex(dir, "add", "Parent", "of", "things", "--vextype", "abstract")
    local child = vex(dir, "add", "Child", "of", "things", "--vextype", "atom")
    local dependent = vex(dir, "add", "Dependent", "on", "child", "--vextype", "atom")
    helper.link(dir, parent, "children", {child})
    helper.link(dir, dependent, "dependencies", {child})
    vex(dir, "resolve", "all")
    local before = helper.read_file(path(child))
    local result = helper.run_vex(dir, {"set", child, "--vextype", "abstract", "--children", dependent})
    assert.is_true(result.code ~= 0, "expected the set to fail")
    assert.equal(before, helper.read_file(path(child)))
    assert.equal(0, count("--filter", "vextype:abstract") - 1, "the index kept the change the file did not")
  end)

  it("saves nothing to the index when resolve all fails " .. AUDIT, function()
    local ok = vex(dir, "add", "Fine", "task", "here", "--cost", "1")
    local bad = vex(dir, "add", "Bad", "task", "here", "--cost", "1")
    local index = dir .. "/.vex/vexdex/index.bin"
    local before = helper.read_file(index)
    edit(bad, "\ncost: 1\n", "\ncost: lots\n")
    edit(ok, "\ncost: 1\n", "\ncost: 2\n")
    local result = helper.run_vex(dir, {"resolve", "all"})
    assert.is_true(result.code ~= 0)
    assert.equal(before, helper.read_file(index))
  end)

  it("saves the index once a command succeeds " .. AUDIT, function()
    local vexid = vex(dir, "add", "Saved", "task", "here", "--cost", "1")
    vex(dir, "set", vexid, "--cost", "5")
    assert.equal(1, count("--filter", "cost:5"))
  end)
end)
