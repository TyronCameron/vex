local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

describe("vex storage (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.project()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function snapshot()
    local files = {}
    for _, vexid in ipairs({"child-task-here-1", "parent-abstract-here-1", "dependent-atom-here-1"}) do
      files[vexid] = helper.read_file(dir .. "/" .. vexid .. ".md")
    end
    return files
  end

  local function linked_project()
    local child = vex(dir, "add", "Child", "task", "here", "--cost", "5", "--due", "2026-08-01T09:00:00", "--vexbody", "Notes about the child")
    local parent = vex(dir, "add", "Parent", "abstract", "here", "--vextype", "abstract")
    local dependent = vex(dir, "add", "Dependent", "atom", "here", "--vextype", "atom")
    helper.link(dir, parent, "children", {child})
    helper.link(dir, dependent, "dependencies", {child})
    vex(dir, "resolve", "all")
  end

  it("leaves task files untouched when resolving them again", function()
    linked_project()
    local before = snapshot()
    vex(dir, "resolve", "all")
    vex(dir, "resolve", "all")
    assert.same(before, snapshot())
  end)

  it("keeps the body and every field through a set", function()
    local vexid = vex(dir, "add", "Keep", "my", "notes", "--cost", "5", "--vexbody", "Line one")
    vex(dir, "set", vexid, "--benefit", "2")
    local content = helper.read_file(dir .. "/" .. vexid .. ".md")
    local fields = helper.frontmatter(dir .. "/" .. vexid .. ".md")
    assert.equal("5", fields.cost)
    assert.equal("2", fields.benefit)
    assert.truthy(content:find("\n%-%-%-\nLine one"))
  end)

  it("picks up a hand-edited task file on resolve all", function()
    local vexid = vex(dir, "add", "Edited", "by", "hand")
    local path = dir .. "/" .. vexid .. ".md"
    helper.write_file(path, helper.read_file(path):gsub("\nstatus: todo\n", "\nstatus: todo\ncost: 9\n"))
    vex(dir, "resolve", "all")
    assert.truthy(vex(dir, "get", vexid, "--cost"):find("9", 1, true))
  end)

  it("keeps a hand-written natural-language time until vex next writes the task as a date", function()
    local vexid = vex(dir, "add", "Hand", "dated", "task")
    local path = dir .. "/" .. vexid .. ".md"
    helper.write_file(path, helper.read_file(path):gsub("\nstatus: todo\n", "\nstatus: todo\ndue: tomorrow 8am\n"))
    vex(dir, "resolve", "all")
    vex(dir, "set", vexid, "--cost", "1")
    local t = os.date("*t", os.time() + 86400)
    assert.equal(string.format("%04d-%02d-%02d 08:00:00", t.year, t.month, t.day), helper.frontmatter(path).due)
  end)

  it("rebuilds a deleted index from the task files", function()
    linked_project()
    os.execute("rm -f " .. helper.shell_escape(dir) .. "/.vex/vexdex/*")
    vex(dir, "resolve", "all")
    assert.truthy(vex(dir, "focus", "all"):find("Focusing on 3 vexes", 1, true))
    assert.truthy(vex(dir, "view", "child-task-here-1", "singular"):find("parent-abstract-here-1", 1, true))
  end)

  it("rebuilds a missing vexdex folder, as in a fresh clone", function()
    linked_project()
    os.execute("rm -rf " .. helper.shell_escape(dir .. "/.vex/vexdex"))
    vex(dir, "resolve", "all")
    assert.truthy(vex(dir, "focus", "all"):find("Focusing on 3 vexes", 1, true))
    assert.truthy(helper.is_file(dir .. "/.vex/vexdex/index.bin"))
  end)

  it("never writes transients to a task file", function()
    linked_project()
    for _, vexid in ipairs({"child-task-here-1", "parent-abstract-here-1", "dependent-atom-here-1"}) do
      local fields = helper.frontmatter(dir .. "/" .. vexid .. ".md")
      for _, transient in ipairs({"wordcount", "phase", "blockers", "lineage", "parent", "path", "age"}) do
        assert.is_nil(fields[transient], transient .. " was written to " .. vexid)
      end
    end
  end)

  it("leaves nothing behind in .vex/tmp", function()
    linked_project()
    vex(dir, "set", "child-task-here-1", "--status", "done")
    local handle = io.popen("ls -A " .. helper.shell_escape(dir .. "/.vex/tmp") .. " | grep -v '^.gitignore$'")
    assert.equal("", handle:read("*a"))
    handle:close()
  end)

  it("replays the saved focus's operations on each run", function()
    local kept = vex(dir, "add", "Still", "to", "do")
    local started = vex(dir, "add", "Started", "already")
    vex(dir, "focus", "all", "--filter", "status:todo")
    vex(dir, "set", started, "--status", "done")
    local out = vex(dir, "get")
    assert.truthy(out:find(kept, 1, true))
    assert.is_nil(out:find(started, 1, true))
  end)

  it("rebuilds the same tasks elsewhere by replaying the verb log", function()
    vex(dir, "add", "Plan", "a", "trip", "--vextype", "abstract")
    vex(dir, "add", "Book", "flights", "--cost", "5", "--vexbody", "Window seat, please")
    vex(dir, "set", "plan-trip-1", "--insert", "--children", "book-flights-1")
    vex(dir, "recipe", "abstract", "Pack", "bags")
    vex(dir, "focus", "book-flights-1")
    vex(dir, "set", "--status", "done")
    vex(dir, "add", "Throw", "this", "away")
    vex(dir, "remove", "throw-away-1")

    local replay = helper.project()
    for line in io.lines(dir .. "/.vex/vexdex/verb-log.txt") do
      local raw = line:match("^[^\t]*\t(.*)$")
      local status = os.execute("cd " .. helper.shell_escape(replay) .. " && " .. helper.shell_escape(helper.VEX_BIN) .. " " .. raw .. " >/dev/null 2>&1")
      assert.is_true(status == 0 or status == true, "replaying `" .. raw .. "` failed")
    end

    local function tasks(project)
      local result = {}
      for _, vexid in ipairs({"plan-trip-1", "book-flights-1", "pack-bags-1"}) do
        local path = helper.task_file(project, vexid)
        local fields = helper.frontmatter(path)
        fields.created, fields.modified = nil, nil
        result[vexid] = {fields, helper.read_file(path):match("\n%-%-%-\n(.*)$")}
      end
      result.removed = helper.task_file(project, "throw-away-1")
      return result
    end
    local original, replayed = tasks(dir), tasks(replay)
    helper.rm_tmp_dir(replay)
    assert.same(original, replayed)
    assert.are.equal("done", replayed["book-flights-1"][1].status)
  end)

end)
