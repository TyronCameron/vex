local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

describe("vex global config and extensions (e2e, subprocess)", function()
  local dir, home

  before_each(function()
    dir = helper.project()
    home = helper.make_tmp_dir()
    helper.vex_home = home
  end)

  after_each(function()
    helper.vex_home = "/nonexistent/vex-home"
    helper.rm_tmp_dir(dir)
    helper.rm_tmp_dir(home)
  end)

  local function globally(path, code)
    os.execute("mkdir -p " .. helper.shell_escape((home .. "/" .. path):match("^(.+)/[^/]+$")))
    helper.write_file(home .. "/" .. path, code)
  end

  local function locally(path, code)
    helper.write_file(dir .. "/.vex/" .. path, code)
  end

  it("applies settings from the global config.lua", function()
    globally("config.lua", "return { paths = { groupby = {'status'} } }")
    local vexid = vex(dir, "add", "Grouped", "globally")
    assert.truthy(helper.task_file(dir, vexid):find("/todo/" .. vexid .. ".md", 1, true))
  end)

  it("lets the project's config.lua override the global one", function()
    globally("config.lua", "return { paths = { groupby = {'status'} } }")
    helper.write_file(dir .. "/.vex/config.lua", "return { taskfolder = '.', paths = { groupby = {} } }")
    local vexid = vex(dir, "add", "Flat", "locally")
    assert.equal(dir .. "/" .. vexid .. ".md", helper.task_file(dir, vexid))
  end)

  it("loads extensions from the global folders", function()
    globally("tasks/bug.lua", [[
      task:task 'bug':extends 'task' {
        schema = schema.atleast { severity = schema.any {'low', 'high'} }
      }
    ]])
    assert.are.equal(0, helper.run_vex(dir, {"add", "Crash", "on", "start", "--vextype", "bug", "--severity", "high"}).code)
    assert.are_not.equal(0, helper.run_vex(dir, {"add", "Typo", "in", "docs", "--vextype", "bug", "--severity", "meh"}).code)
  end)

  it("loads the project's extensions after the global ones", function()
    globally("tasks/bug.lua", [[
      task:task 'bug':extends 'task' {
        schema = schema.atleast { severity = schema.any {'low', 'high'} }
      }
    ]])
    locally("tasks/crash.lua", [[
      task:task 'crash':extends 'bug' {
        schema = schema.atleast { }
      }
    ]])
    assert.are.equal(0, helper.run_vex(dir, {"add", "Crash", "on", "start", "--vextype", "crash", "--severity", "high"}).code)
  end)

  it("lets a global plugin replace a slot's default", function()
    globally("plugin/canonicalvexid.lua", [[
      return { generate = function(_, lookup)
        local n = 1
        while lookup['mine-' .. n] do n = n + 1 end
        return 'mine-' .. n
      end }
    ]])
    assert.equal("mine-1", vex(dir, "add", "Anything", "at", "all"))
  end)

  it("registers standalone plugins from the global plugin folder", function()
    globally("plugin/hello.lua", [[
      local cli = require 'lib.cli'
      cli:verb "hello" { function() print('hello from the global folder') end, doc = "Greet", args = "", example = "vex hello" }
      return {}
    ]])
    assert.equal("hello from the global folder", vex(dir, "hello"))
  end)

  it("ignores a global folder that does not exist", function()
    helper.vex_home = home .. "/missing"
    assert.equal("add-plain-task-1", vex(dir, "add", "Add", "plain", "task"))
  end)
end)
