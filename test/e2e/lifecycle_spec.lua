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

  it("descendants transient field appears in show/get/view but never on disk", function()
    helper.run_vex(dir, {"init"})

    local child_id = helper.trim(
      helper.run_vex(dir, {"add", "Write", "changelog", "--vextype", "atom"}).stdout
    )

    -- setting a list field (children) via CLI flag isn't implemented yet
    -- (see implement-cli-list-fields-1), so wire up the parent's children
    -- directly on disk in the same multi-line array format the writer uses.
    local parent_path = dir .. "/parent-task-1.md"
    local f = assert(io.open(parent_path, "w"))
    f:write(table.concat({
      "---",
      "vexid: parent-task-1",
      "vextype: abstract",
      "description: Parent task",
      "children:",
      '  - "[[' .. child_id .. ']]"',
      'created: "2026-07-22 12:00:00"',
      'modified: "2026-07-22 12:00:00"',
      "status: todo",
      "---",
      "",
    }, "\n"))
    f:close()

    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)

    local show_result = helper.strip_ansi(helper.run_vex(dir, {"show", "parent-task-1"}).stdout)
    assert.is_not_nil(show_result:find("descendants: 1", 1, true))

    local get_result = helper.strip_ansi(
      helper.run_vex(dir, {"get", "parent-task-1", "--descendants"}).stdout
    )
    assert.is_not_nil(get_result:find("1", 1, true))

    local csv_result = helper.strip_ansi(helper.run_vex(dir, {"view", "all", "csv"}).stdout)
    assert.is_not_nil(csv_result:find("descendants", 1, true))

    local on_disk = helper.read_file(parent_path)
    assert.is_nil(on_disk:find("descendants", 1, true))
  end)

  it("focus --select can select a transient field, alongside vexid", function()
    helper.run_vex(dir, {"init"})

    local child_id = helper.trim(
      helper.run_vex(dir, {"add", "Write", "changelog", "--vextype", "atom"}).stdout
    )
    local parent_path = dir .. "/parent-task-1.md"
    local f = assert(io.open(parent_path, "w"))
    f:write(table.concat({
      "---",
      "vexid: parent-task-1",
      "vextype: abstract",
      "description: Parent task",
      "children:",
      '  - "[[' .. child_id .. ']]"',
      'created: "2026-07-22 12:00:00"',
      'modified: "2026-07-22 12:00:00"',
      "status: todo",
      "---",
      "",
    }, "\n"))
    f:close()

    assert.are.equal(0, helper.run_vex(dir, {"resolve", "all"}).code)
    assert.are.equal(0, helper.run_vex(dir, {"focus", "all", "--select", "descendants"}).code)

    local csv_result = helper.strip_ansi(helper.run_vex(dir, {"view", "prev", "csv"}).stdout)
    assert.is_not_nil(csv_result:find("vexid,descendants", 1, true))
    assert.is_not_nil(csv_result:find("parent-task-1,1", 1, true))
  end)
end)
