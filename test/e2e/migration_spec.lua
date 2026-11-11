local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

local SCRIPT = helper.VEX_BIN:gsub("src/vex$", "scripts/migrate-parents.lua")

describe("migrating children and options to parent (e2e, subprocess)", function()
  local dir

  local function write(vexid, fields)
    helper.write_file(dir .. "/" .. vexid .. ".md", "---\nvexid: " .. vexid .. "\n" .. fields .. "created: \"2026-01-01 09:00:00\"\nmodified: \"2026-01-01 09:00:00\"\n---\n")
  end

  local function migrate()
    local handle = assert(io.popen("cd " .. helper.shell_escape(dir) .. " && luajit " .. helper.shell_escape(SCRIPT) .. " . 2>&1; echo \"exit:$?\""))
    local output = handle:read("*a")
    handle:close()
    local body, code = output:match("^(.*)exit:(%d+)%s*$")
    return tonumber(code), body
  end

  local function task(vexid)
    return helper.frontmatter(helper.task_file(dir, vexid))
  end

  before_each(function()
    dir = helper.project()
    write("plan-trip-1", 'vextype: abstract\ndescription: Plan the trip\nchildren:\n  - "[[book-travel-1]]"\n  - "[[pick-hotel-1]]"\n')
    write("book-travel-1", 'vextype: abstract\ndescription: Book the travel\nchildren:\n  - "[[book-flights-1]]"\n')
    write("book-flights-1", 'vextype: atom\ndescription: Book the flights\nstatus: todo\n')
    write("pick-hotel-1", 'vextype: decision\ndescription: Pick a hotel\nstatus: todo\noptions:\n  - "[[hotel-one-1]]"\n  - "[[hotel-two-1]]"\ndecision: "[[hotel-two-1]]"\n')
    write("hotel-one-1", 'vextype: exploration\ndescription: Look at hotel one\nstatus: todo\n')
    write("hotel-two-1", 'vextype: exploration\ndescription: Look at hotel two\nstatus: todo\n')
    write("children-empty-1", 'vextype: abstract\ndescription: Empty abstract here\nchildren: []\n')
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  it("gives every child and option its parent and drops the lists", function()
    local code, output = migrate()
    assert.equal(0, code, output)
    vex(dir, "resolve", "all", "--force")
    assert.equal("[[plan-trip-1]]", task("book-travel-1").parent)
    assert.equal("[[plan-trip-1]]", task("pick-hotel-1").parent)
    assert.equal("[[book-travel-1]]", task("book-flights-1").parent)
    assert.equal("[[pick-hotel-1]]", task("hotel-one-1").parent)
    assert.equal("[[pick-hotel-1]]", task("hotel-two-1").parent)
    assert.is_nil(task("plan-trip-1").parent)
    for _, vexid in ipairs({"plan-trip-1", "book-travel-1", "pick-hotel-1", "children-empty-1"}) do
      assert.is_nil(task(vexid).children, vexid)
      assert.is_nil(task(vexid).options, vexid)
    end
    assert.equal("[[hotel-two-1]]", task("pick-hotel-1").decision)
    assert.equal("plan-trip-1,book-travel-1", vex(dir, "get", "book-flights-1", "--lineage"))
  end)

  it("changes nothing when run again", function()
    assert.equal(0, (migrate()))
    local before = helper.read_file(dir .. "/book-flights-1.md")
    local code, output = migrate()
    assert.equal(0, code, output)
    assert.equal(before, helper.read_file(dir .. "/book-flights-1.md"))
  end)

  it("refuses to write anything when a task is listed by two parents", function()
    write("other-parent-1", 'vextype: abstract\ndescription: Another parent here\nchildren:\n  - "[[book-flights-1]]"\n')
    local before = helper.read_file(dir .. "/plan-trip-1.md")
    local code, output = migrate()
    assert.is_not.equal(0, code)
    assert.truthy(output:find("book-flights-1", 1, true), output)
    assert.equal(before, helper.read_file(dir .. "/plan-trip-1.md"))
    assert.is_nil(task("book-flights-1").parent)
  end)

  it("refuses to write anything when a listed task has no file", function()
    write("dangling-parent-1", 'vextype: abstract\ndescription: Dangling parent here\nchildren:\n  - "[[no-such-task-1]]"\n')
    local code, output = migrate()
    assert.is_not.equal(0, code)
    assert.truthy(output:find("no-such-task-1", 1, true), output)
    assert.is_nil(task("book-flights-1").parent)
  end)
end)
