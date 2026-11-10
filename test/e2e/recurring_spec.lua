local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

describe("recurring and repeated tasks (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.project()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function task(vexid)
    return helper.frontmatter(assert(helper.task_file(dir, vexid), "no task file for " .. vexid))
  end

  local function vexids(output)
    local found = {}
    for vexid in output:gmatch("%S+") do table.insert(found, vexid) end
    return found
  end

  local function exists(vexid)
    return helper.task_file(dir, vexid) ~= nil
  end

  local function plain()
    helper.write_file(dir .. "/.vex/config.lua", "return { paths = { groupby = {} }, plugins = { vexations = false } }")
  end

  local function daysfromtoday(days)
    local t = os.date("*t")
    return os.date("%Y-%m-%d %H:%M:%S", os.time({year = t.year, month = t.month, day = t.day + days, hour = 0, isdst = false}))
  end

  describe("the recurring recipe without vexations", function()
    before_each(plain)

    it("adds one task that recurs over its due date", function()
      assert.equal("wash-dishes-1", vex(dir, "recipe", "recurring", "Wash", "dishes", "--start", "today", "--recur", "weekly"))
      local fields = task("wash-dishes-1")
      assert.equal("task", fields.vextype)
      assert.equal("weekly", fields.recur)
      assert.equal("due", fields.over)
      assert.equal(daysfromtoday(0), fields.due)
      assert.is_false(exists("wash-dishes-2"))
    end)

    it("adds the next task, its due date a recurrence later, when the task is done", function()
      vex(dir, "recipe", "recurring", "Wash", "dishes", "--start", "today", "--recur", "weekly", "--vexbody", "Scrub the pots too")
      vex(dir, "set", "wash-dishes-1", "--status", "done")
      local fields = task("wash-dishes-2")
      assert.equal("Wash dishes", fields.description)
      assert.equal("todo", fields.status)
      assert.equal("weekly", fields.recur)
      assert.equal(daysfromtoday(7), fields.due)
      assert.truthy(helper.read_file(helper.task_file(dir, "wash-dishes-2")):find("Scrub the pots too", 1, true))
      assert.equal("done", task("wash-dishes-1").status)
    end)

    it("recurs a task given a recurrence with vex set", function()
      vex(dir, "add", "Water", "the", "plants", "--due", "today")
      vex(dir, "set", "water-plants-1", "--recur", "3 days")
      vex(dir, "set", "water-plants-1", "--status", "done")
      assert.equal(daysfromtoday(3), task("water-plants-2").due)
    end)

    it("recurs over another date field", function()
      helper.write_file(dir .. "/.vex/tasks/review.lua", [[
        task:task 'review':extends 'task' {
          schema = schema.atleast { reviewed = schema.maybe {schema.formatted {schema.datetime}} }
        }
      ]])
      vex(dir, "recipe", "recurring", "Review", "budget", "--vextype", "review", "--start", "today", "--recur", "monthly", "--over", "reviewed")
      vex(dir, "set", "review-budget-1", "--status", "done")
      local t = os.date("*t")
      local expected = os.date("%Y-%m-%d %H:%M:%S", os.time({year = t.year, month = t.month + 1, day = t.day, hour = 0, isdst = false}))
      assert.equal(expected, task("review-budget-2").reviewed)
    end)

    it("adds the next task when the task is marked done by hand", function()
      vex(dir, "recipe", "recurring", "Wash", "dishes", "--start", "today", "--recur", "daily")
      local path = helper.task_file(dir, "wash-dishes-1")
      helper.write_file(path, (helper.read_file(path):gsub("status: todo", "status: done")))
      vex(dir, "resolve", "all")
      assert.equal(daysfromtoday(1), task("wash-dishes-2").due)
    end)

    it("adds only one next task, however often the done task resolves again", function()
      vex(dir, "recipe", "recurring", "Wash", "dishes", "--start", "today", "--recur", "weekly")
      vex(dir, "set", "wash-dishes-1", "--status", "done")
      vex(dir, "set", "wash-dishes-1", "--status", "done")
      vex(dir, "resolve", "all")
      vex(dir, "resolve", "all", "--force")
      vex(dir, "resolve", "wash-dishes-1", "--force")
      assert.is_true(exists("wash-dishes-2"))
      assert.is_false(exists("wash-dishes-3"))
    end)

    it("refuses a recurrence it cannot read", function()
      helper.vex_fails(dir, "recurrence", "recipe", "recurring", "Wash", "dishes", "--recur", "sometimes")
    end)

    it("refuses to recur over a field that is not a date", function()
      helper.vex_fails(dir, "date field", "add", "Wash", "dishes", "--recur", "weekly", "--over", "cost")
    end)
  end)

  describe("the recurring recipe with vexations", function()
    it("adds an abstract first and the recurring task inside it", function()
      local output = vex(dir, "recipe", "recurring", "Wash", "dishes", "--start", "today", "--recur", "weekly")
      assert.same({"wash-dishes-1", "wash-dishes-2"}, vexids(output))
      local abstract = task("wash-dishes-1")
      assert.equal("abstract", abstract.vextype)
      assert.equal("[[wash-dishes-1]]", task("wash-dishes-2").parent)
      assert.equal("wash-dishes-2", vex(dir, "get", "wash-dishes-1", "--children"))
      assert.equal("weekly", task("wash-dishes-2").recur)
      assert.is_nil(abstract.recur)
    end)

    it("puts each next task inside the same abstract", function()
      vex(dir, "recipe", "recurring", "Wash", "dishes", "--start", "today", "--recur", "weekly")
      vex(dir, "set", "wash-dishes-2", "--status", "done")
      assert.equal("[[wash-dishes-1]]", task("wash-dishes-3").parent)
      assert.equal("wash-dishes-2,wash-dishes-3", vex(dir, "get", "wash-dishes-1", "--children"))
      assert.equal(daysfromtoday(7), task("wash-dishes-3").due)
    end)
  end)

  describe("the repeat recipe", function()
    it("adds the task n times without vexations", function()
      plain()
      local output = vex(dir, "recipe", "repeat", "Wash", "dishes", "--n", "3", "--cost", "2")
      assert.same({"wash-dishes-1", "wash-dishes-2", "wash-dishes-3"}, vexids(output))
      assert.equal("2", task("wash-dishes-3").cost)
      assert.is_false(exists("wash-dishes-4"))
    end)

    it("adds an abstract first and the n tasks inside it with vexations", function()
      vex(dir, "recipe", "repeat", "Wash", "dishes", "--n", "2")
      local abstract = task("wash-dishes-1")
      assert.equal("abstract", abstract.vextype)
      assert.equal("[[wash-dishes-1]]", task("wash-dishes-2").parent)
      assert.equal("[[wash-dishes-1]]", task("wash-dishes-3").parent)
      assert.equal("wash-dishes-2,wash-dishes-3", vex(dir, "get", "wash-dishes-1", "--children"))
      assert.is_nil(abstract.n)
      assert.is_nil(task("wash-dishes-2").n)
    end)

    it("refuses a count that is not a whole number above 0", function()
      helper.vex_fails(dir, "--n", "recipe", "repeat", "Wash", "dishes", "--n", "0")
      helper.vex_fails(dir, "--n", "recipe", "repeat", "Wash", "dishes", "--n", "lots")
      helper.vex_fails(dir, "--n", "recipe", "repeat", "Wash", "dishes")
    end)
  end)
end)
