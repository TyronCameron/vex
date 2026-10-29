local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex, fails = helper.vex, helper.vex_fails

describe("vex user-facing errors (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.project()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local cases = {
    {"an unknown verb", "unknown verb 'frobnicate'", {"frobnicate"}},
    {"an unknown focus", "unknown focus with name: nosuch", {"show", "nosuch"}},
    {"an unknown view", "A view of name `nope` does not exist", {"view", "all", "nope"}},
    {"an unknown recipe", "A recipe of name `nope` does not exist", {"recipe", "nope", "Hello", "there"}},
    {"an unknown vextype", "Type  = nope", {"add", "Bad", "type", "thing", "--vextype", "nope"}},
    {"a description that is too short", "Need more than 3 characters", {"add", "abc"}},
    {"vex init inside a project", "Already in a vex directory", {"init"}},
    {"a filter without a value", "You need to provide a field and value", {"focus", "all", "--filter", "status"}},
    {"an unknown shell", "is not known", {"autocomplete", "nosuchshell"}},
    {"an unknown focus operation", "Unknown focus operation `bogus`", {"focus", "all", "--bogus", "x"}},
  }

  for _, case in ipairs(cases) do
    it("rejects " .. case[1], function()
      fails(dir, case[2], unpack(case[3]))
    end)
  end

  it("rejects a phrase --interpret cannot read", function()
    vex(dir, "add", "Due", "some", "day", "--due", "2026-08-01")
    fails(dir, "Cannot interpret `tomorrow blorp`", "focus", "all", "--interpret", "--between", "due:tomorrow blorp:")
  end)

  it("stops a command whose event hook fails, naming the hook", function()
    local vexid = vex(dir, "add", "Unowned", "task")
    local path = dir .. "/" .. vexid .. ".md"
    local before = helper.read_file(path)
    helper.write_file(dir .. "/.vex/events/owners.lua", [[
      event:register('pre-verb-set', 'needs-owner', function() error('every task needs an owner', 0) end)
    ]])
    local stderr = fails(dir, "Event hook 'needs-owner' failed on 'pre-verb-set': every task needs an owner", "set", vexid, "--cost", "3")
    assert.is_not_nil(stderr:find("hook in .vex/events", 1, true))
    assert.are.equal(before, helper.read_file(path))
  end)

  it("rejects any verb outside a project", function()
    local outside = helper.make_tmp_dir()
    fails(outside, "Not in a vex directory", "show", "all")
    helper.rm_tmp_dir(outside)
  end)

  it("rejects vex init with arguments", function()
    local fresh = helper.make_tmp_dir()
    fails(fresh, "You cannot provide args to vex init", "init", "here")
    helper.rm_tmp_dir(fresh)
  end)

  it("rejects the singular view of more than one task", function()
    vex(dir, "add", "First", "task")
    vex(dir, "add", "Second", "task")
    fails(dir, "only accepts focuses which have a single task", "view", "all", "singular")
  end)

  it("rejects a skipped status transition and leaves the task unchanged", function()
    local vexid = vex(dir, "add", "Water", "the", "plants")
    fails(dir, "validation step failed", "set", vexid, "--status", "done")
    assert.equal("todo", helper.frontmatter(dir .. "/" .. vexid .. ".md").status)
  end)

  it("rejects an unknown set modifier", function()
    local vexid = vex(dir, "add", "Water", "the", "plants")
    fails(dir, "Unknown modifier `frobnicate`", "set", vexid, "--frobnicate", "--status", "done")
  end)

  it("rejects a link to a task that does not exist", function()
    local vexid = vex(dir, "add", "Dangling", "link", "task")
    helper.link(dir, vexid, "dependencies", {"no-such-task-1"})
    fails(dir, "validation step failed", "resolve", "all")
  end)

  it("rejects a task that is a child of two abstracts", function()
    local child = vex(dir, "add", "Shared", "child", "task")
    local first = vex(dir, "add", "First", "parent", "--vextype", "abstract")
    local second = vex(dir, "add", "Second", "parent", "--vextype", "abstract")
    helper.link(dir, first, "children", {child})
    helper.link(dir, second, "children", {child})
    fails(dir, "cannot be a child of both", "resolve", "all")
  end)

  it("rejects a task file without a vextype", function()
    helper.write_file(dir .. "/no-type-1.md", "---\nvexid: no-type-1\ndescription: No type here\nstatus: todo\n---\n")
    fails(dir, "field = vextype", "resolve", "all")
  end)

  it("rejects an abstract listing itself as a child", function()
    local parent = vex(dir, "add", "Self", "parent", "--vextype", "abstract")
    fails(dir, "cannot be a child of itself", "set", parent, "--children", parent)
  end)

  it("rejects changing a vexid", function()
    local vexid = vex(dir, "add", "Fixed", "name", "task")
    fails(dir, "cannot be changed", "set", vexid, "--vexid", "renamed-1")
  end)

  it("rejects a dependency cycle", function()
    local first = vex(dir, "add", "Cycle", "first", "task")
    local second = vex(dir, "add", "Cycle", "second", "task")
    helper.link(dir, first, "dependencies", {second})
    helper.link(dir, second, "dependencies", {first})
    fails(dir, "already depends on it", "resolve", "all")
  end)

  it("rejects a dependency on a task with children", function()
    local leaf = vex(dir, "add", "Grouped", "leaf", "task")
    local parent = vex(dir, "add", "Grouping", "parent", "--vextype", "abstract")
    local dependent = vex(dir, "add", "Needy", "dependent", "task")
    helper.link(dir, parent, "children", {leaf})
    fails(dir, "has children", "set", dependent, "--dependencies", parent)
  end)

  it("rejects dependencies on an abstract", function()
    local leaf = vex(dir, "add", "Plain", "leaf", "task")
    local parent = vex(dir, "add", "Needy", "parent", "--vextype", "abstract")
    fails(dir, "validation step failed", "set", parent, "--dependencies", leaf)
  end)
end)
