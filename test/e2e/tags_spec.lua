local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'

describe("vex tags (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.project()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function rules(source)
    local config = dir .. "/.vex/config.lua"
    helper.write_file(config, (helper.read_file(config):gsub("^return {", "return {\n  autotags = {" .. source .. "},", 1)))
  end

  local function fields(vexid)
    return helper.frontmatter(helper.task_file(dir, vexid))
  end

  it("writes no tags without rules or manual tags", function()
    local vexid = helper.vex(dir, "add", "Plain", "untagged", "task")
    assert.is_nil(fields(vexid).tags)
    assert.is_nil(fields(vexid).manualtags)
  end)

  it("tags a task by the rules, following its changes", function()
    rules("open = function(t) return t.phase ~= 'final' end")
    local vexid = helper.vex(dir, "add", "Ruled", "open", "task")
    assert.same({"#open"}, fields(vexid).tags)
    helper.vex(dir, "set", vexid, "--status", "done")
    assert.is_nil(fields(vexid).tags)
  end)

  it("keeps a suppressed tag off and a pinned tag on whatever the rules say", function()
    rules("open = function(t) return t.phase ~= 'final' end")
    local vexid = helper.vex(dir, "add", "Overridden", "tagged", "task")
    helper.vex(dir, "set", vexid, "--insert", "--manualtags", "-open,pinned")
    assert.same({"#pinned"}, fields(vexid).tags)
    assert.same({"-#open", "#pinned"}, fields(vexid).manualtags)
    helper.vex(dir, "set", vexid, "--insert", "--manualtags", "open")
    assert.same({"#open", "#pinned"}, fields(vexid).tags)
    assert.same({"#pinned", "#open"}, fields(vexid).manualtags)
  end)

  it("applies changed rules on a forced resolve and keeps the manual tags", function()
    rules("old = function() return true end")
    local vexid = helper.vex(dir, "add", "Rechecked", "tagged", "task", "--manualtags", "pinned")
    assert.same({"#old", "#pinned"}, fields(vexid).tags)
    local config = dir .. "/.vex/config.lua"
    helper.write_file(config, (helper.read_file(config):gsub("old = ", "new = ")))
    helper.vex(dir, "resolve", "all", "--force")
    assert.same({"#new", "#pinned"}, fields(vexid).tags)
  end)

  it("picks up hand edits to manual tags and overwrites hand edits to tags", function()
    local vexid = helper.vex(dir, "add", "Hand", "edited", "task")
    local path = helper.task_file(dir, vexid)
    helper.write_file(path, (helper.read_file(path):gsub("\n%-%-%-\n", '\nmanualtags:\n  - "#mine"\ntags:\n  - "#bogus"\n---\n', 1)))
    helper.vex(dir, "resolve", "all")
    assert.same({"#mine"}, fields(vexid).tags)
  end)

  it("leaves the file alone when nothing changes", function()
    rules("open = function() return true end")
    local vexid = helper.vex(dir, "add", "Steady", "tagged", "task")
    local before = helper.read_file(helper.task_file(dir, vexid))
    helper.vex(dir, "resolve", vexid, "--force")
    assert.equal(before, helper.read_file(helper.task_file(dir, vexid)))
  end)

  it("focuses on the tasks holding a tag", function()
    rules("cheap = function(t) return (t.cost or 0) < 5 end")
    local cheap = helper.vex(dir, "add", "Cheap", "tagged", "task", "--cost", "1")
    helper.vex(dir, "add", "Pricey", "tagged", "task", "--cost", "9")
    helper.vex(dir, "focus", "all", "--contains", "tags:cheap")
    assert.equal(cheap, helper.vex(dir, "get", "prev"))
  end)

end)
