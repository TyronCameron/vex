local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'

describe("vex owner (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.make_tmp_dir()
    helper.run_vex(dir, {"init"})
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function users(...)
    local names = {}
    for _, name in ipairs({...}) do table.insert(names, string.format("%q", name)) end
    local f = assert(io.open(dir .. "/.vex/config.lua", "w"))
    f:write("return { taskfolder = '.', users = {" .. table.concat(names, ", ") .. "} }")
    f:close()
  end

  it("accepts an owner listed in the config's users", function()
    users("alice", "bob")
    local res = helper.run_vex(dir, {"add", "Owned", "task", "--owner", "alice"})
    assert.are.equal(0, res.code)
    assert.truthy(helper.read_file(dir .. "/owned-task-1.md"):find("owner: alice", 1, true))
  end)

  it("rejects an owner missing from the config's users", function()
    users("alice")
    assert.are_not.equal(0, helper.run_vex(dir, {"add", "Stranger", "task", "--owner", "mallory"}).code)
  end)

  it("rejects any owner when no users are configured", function()
    assert.are_not.equal(0, helper.run_vex(dir, {"add", "Lonely", "task", "--owner", "alice"}).code)
  end)

  it("leaves owner optional", function()
    users("alice")
    assert.are.equal(0, helper.run_vex(dir, {"add", "Unowned", "task"}).code)
  end)

  it("ranks each owner's open tasks by due date as their urgency", function()
    users("alice", "bob")
    local first = helper.vex(dir, "add", "Alice", "first", "job", "--owner", "alice", "--due", "2026-01-01")
    local second = helper.vex(dir, "add", "Alice", "second", "job", "--owner", "alice", "--due", "2026-02-01")
    local only = helper.vex(dir, "add", "Bob", "only", "job", "--owner", "bob", "--due", "2026-03-01")
    local undated = helper.vex(dir, "add", "Alice", "undated", "job", "--owner", "alice")
    for vexid, urgency in pairs({[first] = "1", [second] = "2", [only] = "1", [undated] = "3"}) do
      assert.equal(urgency, helper.vex(dir, "get", vexid, "--urgency"), vexid)
    end
  end)
end)
