local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'

describe("vex extensions in .vex (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.make_tmp_dir()
    helper.run_vex(dir, {"init"})
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function extension(path, code)
    local f = assert(io.open(dir .. "/.vex/" .. path, "w"))
    f:write(code)
    f:close()
  end

  it("loads custom task types from .vex/tasks", function()
    extension("tasks/bug.lua", [[
      task:task 'bug':extends 'task' {
        schema = schema.atleast { severity = schema.any {'low', 'high'} }
      }
    ]])
    assert.are.equal(0, helper.run_vex(dir, {"add", "Crash", "on", "start", "--vextype", "bug", "--severity", "high"}).code)
    assert.are_not.equal(0, helper.run_vex(dir, {"add", "Typo", "in", "docs", "--vextype", "bug", "--severity", "meh"}).code)
  end)

  it("reports an extension that fails to load", function()
    extension("tasks/broken.lua", "this is not lua")
    local result = helper.run_vex(dir, {"focus", "all"})
    assert.are_not.equal(0, result.code)
    assert.is_not_nil(result.stderr:find("Could not load the vex extension", 1, true))
  end)
end)
