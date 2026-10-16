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
  }

  for _, case in ipairs(cases) do
    it("rejects " .. case[1], function()
      fails(dir, case[2], unpack(case[3]))
    end)
  end

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

  it("rejects a dependency cycle", function()
    local first = vex(dir, "add", "Cycle", "first", "task")
    local second = vex(dir, "add", "Cycle", "second", "task")
    helper.link(dir, first, "dependencies", {second})
    helper.link(dir, second, "dependencies", {first})
    fails(dir, "already depends on it", "resolve", "all")
  end)
end)
