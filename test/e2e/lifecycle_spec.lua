local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

describe("vex CLI lifecycle (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.project()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function task(vexid)
    return helper.frontmatter(dir .. "/" .. vexid .. ".md")
  end

  it("vex init sets up a project that the other verbs work in", function()
    assert.is_true(helper.is_file(dir .. "/.vex/config.lua"))
    assert.equal("buy-milk-1", vex(dir, "add", "Buy", "milk"))
  end)

  it("vex add writes a resolved task file and vex show prints it", function()
    local vexid = vex(dir, "add", "Make", "coffee", "--importance", "high")
    local fields = task(vexid)
    assert.equal("Make coffee", fields.description)
    assert.equal("task", fields.vextype)
    assert.equal("todo", fields.status)
    assert.equal("high", fields.importance)
    assert.truthy(fields.created:match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$"))
    assert.truthy(vex(dir, "show", vexid):find("coffee", 1, true))
  end)

  it("vex show and vex get print fields as they are written in the task file", function()
    local vexid = vex(dir, "add", "Dated", "task", "--due", "2026-08-01T09:00:00")
    local due = "2026-08-01 09:00:00"
    assert.truthy(vex(dir, "show", vexid):find("due: " .. due, 1, true))
    assert.equal(due, vex(dir, "get", vexid, "--due"))
    assert.truthy(vex(dir, "get", vexid, "--created"):match("^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$"))
  end)

  it("vex get returns the task's selected fields", function()
    vex(dir, "add", "Buy", "milk")
    local out = vex(dir, "get", "all", "--description", "--status")
    assert.truthy(out:find("Buy milk", 1, true))
    assert.truthy(out:find("todo", 1, true))
  end)

  it("vex set changes fields in the task file and keeps the rest", function()
    local vexid = vex(dir, "add", "Buy", "milk", "--cost", "2")
    vex(dir, "set", vexid, "--priority", "1")
    local fields = task(vexid)
    assert.equal("1", fields.priority)
    assert.equal("2", fields.cost)
    assert.equal("Buy milk", fields.description)
  end)

  it("vex set acts on the saved focus when no focus is given", function()
    local milk = vex(dir, "add", "Buy", "milk")
    local eggs = vex(dir, "add", "Buy", "eggs")
    vex(dir, "focus", milk .. "," .. eggs)
    vex(dir, "set", "--owner_note", "shopping")
    assert.equal("shopping", task(milk).owner_note)
    assert.equal("shopping", task(eggs).owner_note)
  end)

  it("vex focus + vex view tabular reference the task", function()
    vex(dir, "add", "Buy", "milk")
    vex(dir, "focus", "all")
    assert.truthy(vex(dir, "view", "all", "tabular"):find("milk", 1, true))
  end)

  it("vex focus takes a comma-separated list of vexids and saves it (implement-cli-list-fields-1)", function()
    local milk = vex(dir, "add", "Buy", "milk")
    local eggs = vex(dir, "add", "Buy", "eggs")
    vex(dir, "add", "Buy", "bread")

    assert.truthy(vex(dir, "focus", milk .. "," .. eggs):find("Focusing on 2 vexes", 1, true))

    local shown = vex(dir, "get")
    assert.truthy(shown:find(milk, 1, true))
    assert.truthy(shown:find(eggs, 1, true))
    assert.is_nil(shown:find("bread", 1, true))
  end)

  it("vex focus initial/interim/final split tasks by status phase (status-resolution-ensure-there-1)", function()
    vex(dir, "add", "Not", "started")
    local doing = vex(dir, "add", "In", "progress")
    local done = vex(dir, "add", "All", "finished")
    vex(dir, "add", "Also", "not", "started")
    vex(dir, "set", doing, "--status", "doing")
    vex(dir, "set", done, "--status", "doing")
    vex(dir, "set", done, "--status", "done")

    assert.truthy(vex(dir, "focus", "initial"):find("Focusing on 2 vexes", 1, true))
    assert.truthy(vex(dir, "focus", "interim"):find("Focusing on 1 vex", 1, true))
    assert.truthy(vex(dir, "get"):find(doing, 1, true))
    assert.truthy(vex(dir, "focus", "final"):find("Focusing on 1 vex", 1, true))
    assert.truthy(vex(dir, "get"):find(done, 1, true))
  end)

  it("vex get reads a transient", function()
    local vexid = vex(dir, "add", "Count", "these", "three")
    assert.equal("3", vex(dir, "get", vexid, "--wordcount"))
  end)

  it("vex view shows transients chosen with --select", function()
    local vexid = vex(dir, "add", "Not", "started")
    vex(dir, "focus", "all", "--select", "phase")
    local out = vex(dir, "view", "csv")
    assert.truthy(out:find("phase", 1, true))
    assert.truthy(out:find(vexid, 1, true))
    assert.truthy(out:find("initial", 1, true))
  end)

  it("vex recipe abstract creates an abstract and focuses on it", function()
    local vexid = vex(dir, "recipe", "abstract", "Create", "more", "vex", "tasks")
    assert.equal("abstract", task(vexid).vextype)
    assert.same({}, task(vexid).children)
    assert.equal(vexid, vex(dir, "get"))
  end)

  it("vex remove deletes the task; a subsequent show fails", function()
    local vexid = vex(dir, "add", "Throwaway", "task")
    vex(dir, "remove", vexid)
    assert.is_false(helper.is_file(dir .. "/" .. vexid .. ".md"))
    helper.vex_fails(dir, "unknown focus", "show", vexid)
  end)

  it("vex add resolves --due/--cost/--benefit instead of failing validation (fix-typed-field-cli-input-1)", function()
    local vexid = vex(dir,
      "add", "Buy", "new", "mug",
      "--cost", "15", "--benefit", "40", "--due", "2026-08-01T09:00:00")
    local fields = task(vexid)
    assert.equal("15", fields.cost)
    assert.equal("40", fields.benefit)
    assert.equal("2026-08-01 09:00:00", fields.due)
  end)

  it("an abstract task survives two consecutive resolve passes (fix-list-field-roundtrip-1)", function()
    vex(dir, "add", "Ship", "v0.2", "--vextype", "abstract")
    vex(dir, "resolve", "all")
    vex(dir, "resolve", "all")
  end)

  it("status only moves todo -> doing -> done (fix-status-transition-enforcement-1)", function()
    local vexid = vex(dir, "add", "Water", "the", "plants")

    helper.vex_fails(dir, "validation step failed", "set", vexid, "--status", "done")
    assert.equal("todo", task(vexid).status)

    vex(dir, "set", vexid, "--status", "doing")
    vex(dir, "set", vexid, "--status", "done")
    assert.equal("done", task(vexid).status)
  end)
end)
