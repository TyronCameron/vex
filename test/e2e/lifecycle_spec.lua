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

  it("vex focus takes a comma-separated list of vexids and saves it (implement-cli-list-fields-1)", function()
    helper.run_vex(dir, {"init"})
    local milk = helper.trim(helper.run_vex(dir, {"add", "Buy", "milk"}).stdout)
    local eggs = helper.trim(helper.run_vex(dir, {"add", "Buy", "eggs"}).stdout)
    helper.run_vex(dir, {"add", "Buy", "bread"})

    local focus_result = helper.run_vex(dir, {"focus", milk .. "," .. eggs})
    assert.are.equal(0, focus_result.code)
    assert.is_not_nil(helper.strip_ansi(focus_result.stdout):find("Focusing on 2 vexes", 1, true))

    local shown = helper.strip_ansi(helper.run_vex(dir, {"get"}).stdout)
    assert.is_not_nil(shown:find(milk, 1, true))
    assert.is_not_nil(shown:find(eggs, 1, true))
    assert.is_nil(shown:find("bread", 1, true))
  end)

  it("vex focus initial/interim/final split tasks by status phase (status-resolution-ensure-there-1)", function()
    helper.run_vex(dir, {"init"})
    helper.run_vex(dir, {"add", "Not", "started"})
    local doing = helper.trim(helper.run_vex(dir, {"add", "In", "progress"}).stdout)
    local done = helper.trim(helper.run_vex(dir, {"add", "All", "finished"}).stdout)
    helper.run_vex(dir, {"add", "Also", "not", "started"})
    helper.run_vex(dir, {"set", doing, "--status", "doing"})
    helper.run_vex(dir, {"set", done, "--status", "doing"})
    helper.run_vex(dir, {"set", done, "--status", "done"})

    local function phase(name)
      local result = helper.run_vex(dir, {"focus", name})
      assert.are.equal(0, result.code)
      return helper.strip_ansi(result.stdout), helper.strip_ansi(helper.run_vex(dir, {"get"}).stdout)
    end

    local initial = phase("initial")
    assert.is_not_nil(initial:find("Focusing on 2 vexes", 1, true))
    local interim, interimids = phase("interim")
    assert.is_not_nil(interim:find("Focusing on 1 vex", 1, true))
    assert.is_not_nil(interimids:find(doing, 1, true))
    local final, finalids = phase("final")
    assert.is_not_nil(final:find("Focusing on 1 vex", 1, true))
    assert.is_not_nil(finalids:find(done, 1, true))
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

  it("vex add resolves --due/--cost/--benefit instead of failing validation (fix-typed-field-cli-input-1)", function()
    helper.run_vex(dir, {"init"})

    -- "T" separator avoids the CLI's separately-tracked space-splitting flag bug.
    local add_result = helper.run_vex(dir, {
      "add", "Buy", "new", "mug",
      "--cost", "15", "--benefit", "40", "--due", "2026-08-01T09:00:00",
    })
    assert.are.equal(0, add_result.code)
    local vexid = helper.trim(add_result.stdout)
    assert.is_true(#vexid > 0)

    local show_result = helper.strip_ansi(helper.run_vex(dir, {"show", vexid}).stdout)
    assert.is_not_nil(show_result:find("cost: 15", 1, true))
    assert.is_not_nil(show_result:find("benefit: 40", 1, true))
    assert.is_not_nil(show_result:find("due: 2026-08-01 09:00:00", 1, true))
  end)

  it("an abstract task survives two consecutive resolve passes (fix-list-field-roundtrip-1)", function()
    helper.run_vex(dir, {"init"})
    local add_result = helper.run_vex(dir, {"add", "Ship", "v0.2", "--vextype", "abstract"})
    assert.are.equal(0, add_result.code)

    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)
    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)
  end)

  it("status only moves todo -> doing -> done (fix-status-transition-enforcement-1)", function()
    helper.run_vex(dir, {"init"})
    local vexid = helper.trim(helper.run_vex(dir, {"add", "Water", "the", "plants"}).stdout)

    local skipped = helper.run_vex(dir, {"set", vexid, "--status", "done"})
    assert.are.not_equal(0, skipped.code)
    assert.is_not_nil(helper.strip_ansi(skipped.stderr):find("validation step failed", 1, true))

    assert.are.equal(0, helper.run_vex(dir, {"set", vexid, "--status", "doing"}).code)
    assert.are.equal(0, helper.run_vex(dir, {"set", vexid, "--status", "done"}).code)
    assert.is_not_nil(helper.read_file(dir .. "/" .. vexid .. ".md"):find("status: done", 1, true))
  end)
end)
