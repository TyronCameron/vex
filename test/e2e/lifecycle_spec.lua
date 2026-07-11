local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'

describe("vex CLI lifecycle (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.make_tmp_dir()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  it("vex init creates a .vex directory with the expected structure", function()
    local result = helper.run_vex(dir, {"init"})
    assert.are.equal(0, result.code)

    assert.is_true(helper.is_dir(dir .. "/.vex"))
    for _, sub in ipairs({"vexdex", "focuses", "views", "tasks", "recipes", "tmp", "events"}) do
      assert.is_true(helper.is_dir(dir .. "/.vex/" .. sub), "missing .vex/" .. sub)
    end

    local cfg = helper.read_file(dir .. "/.vex/config.lua")
    assert.is_not_nil(cfg, "expected .vex/config.lua to exist")
    assert.is_not_nil(cfg:find("taskfolder", 1, true))
  end)

  it("running vex init twice fails with 'already-vexed'", function()
    assert.are.equal(0, helper.run_vex(dir, {"init"}).code)
    local result = helper.run_vex(dir, {"init"})
    assert.are.not_equal(0, result.code)
    assert.is_not_nil(
      helper.strip_ansi(result.stderr):find("Already in a vex directory", 1, true)
    )
  end)

  it("running any verb before init fails with 'not-vexed'", function()
    local result = helper.run_vex(dir, {"show", "whatever"})
    assert.are.not_equal(0, result.code)
    assert.is_not_nil(
      helper.strip_ansi(result.stderr):find("Not in a vex directory", 1, true)
    )
  end)

  it("vex add creates a task and vex show prints it", function()
    helper.run_vex(dir, {"init"})

    local add_result = helper.run_vex(dir, {"add", "Make", "coffee", "--importance", "high"})
    assert.are.equal(0, add_result.code)
    local vexid = helper.trim(add_result.stdout)
    assert.is_true(#vexid > 0)

    local show_result = helper.run_vex(dir, {"show", vexid})
    assert.are.equal(0, show_result.code)
    assert.is_not_nil(helper.strip_ansi(show_result.stdout):find("coffee", 1, true))
  end)

  it("vex get returns the task's selected fields", function()
    helper.run_vex(dir, {"init"})
    helper.run_vex(dir, {"add", "Buy", "milk"})

    local result = helper.run_vex(dir, {"get", "all", "--description", "--id"})
    assert.are.equal(0, result.code)
    assert.is_not_nil(helper.strip_ansi(result.stdout):find("milk", 1, true))
  end)

  it("vex set + vex resolve succeed without error", function()
    helper.run_vex(dir, {"init"})
    local vexid = helper.trim(helper.run_vex(dir, {"add", "Buy", "milk"}).stdout)

    assert.are.equal(0, helper.run_vex(dir, {"set", vexid, "--priority", "1"}).code)
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)
  end)

  it("vex focus + vex view table reference the task", function()
    helper.run_vex(dir, {"init"})
    helper.run_vex(dir, {"add", "Buy", "milk"})

    assert.are.equal(0, helper.run_vex(dir, {"focus", "all"}).code)
    local view_result = helper.run_vex(dir, {"view", "all", "tabular"})
    assert.are.equal(0, view_result.code)
    assert.is_not_nil(helper.strip_ansi(view_result.stdout):find("milk", 1, true))
  end)

  it("vex recipe abstract creates linked tasks", function()
    helper.run_vex(dir, {"init"})
    local result = helper.run_vex(
      dir, {"recipe", "abstract", "Create", "more", "vex", "tasks", "--status", "todo"}
    )
    assert.are.equal(0, result.code)
  end)

  it("vex remove deletes the task; a subsequent show fails", function()
    helper.run_vex(dir, {"init"})
    local vexid = helper.trim(helper.run_vex(dir, {"add", "Throwaway", "task"}).stdout)

    assert.are.equal(0, helper.run_vex(dir, {"remove", vexid}).code)
    assert.are.not_equal(0, helper.run_vex(dir, {"show", vexid}).code)
  end)
end)
