local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

local CHILD = "child-task-here-1"
local PARENT = "parent-abstract-here-1"
local DEPENDENT = "dependent-atom-here-1"
local DECISION = "choose-car-1"

local verbs = {
  {"help"},
  {"help", "add"},
  {"show", CHILD},
  {"show", "all"},
  {"get", "all", "--status", "--cost"},
  {"get", "all", "--select", "status,cost"},
  {"set", DEPENDENT, "--cost", "4"},
  {"set", PARENT, "--insert", "--children", DEPENDENT},
  {"set", PARENT, "--remove", "--children", DEPENDENT},
  {"resolve", "all"},
  {"resolve", CHILD},
  {"focus", "all"},
  {"focus"},
  {"view"},
  {"recipe"},
  {"recipe", "abstract", "Smoke", "recipe", "abstract"},
  {"add", "Smoke", "added", "task"},
  {"add", "Explore", "some", "options", "--vextype", "exploration"},
  {"remove", "smoke-added-task-1"},
  {"version"},
  {"autocomplete", "bash"},
  {"suggest", "2", "vex", "view"},
}

local views = {
  {"view", "all", "csv"},
  {"view", "all", "tabular"},
  {"view", "all", "tabular", "--groupby", "vextype:status", "--orderby", "vexid:desc"},
  {"view", "all", "json"},
  {"view", "all", "kanban"},
  {"view", "all", "overview"},
  {"view", CHILD, "singular"},
  {"view", PARENT, "singular"},
  {"view", DEPENDENT, "singular"},
  {"view", DECISION, "singular"},
  {"view", "none", "csv"},
  {"view", "none", "kanban"},
}

local focuses = {
  {"focus", "none"},
  {"focus", "updated"},
  {"focus", "initial"},
  {"focus", "interim"},
  {"focus", "final"},
  {"focus", "prev"},
  {"focus", CHILD .. "," .. PARENT},
  {"focus", "all", "--filter", "status:todo"},
  {"focus", "all", "--fuzzy", "description:child"},
  {"focus", "all", "--select", "description"},
  {"focus", PARENT, "--tree", "children"},
  {"focus", CHILD, "--reversetree", "children"},
  {"focus", PARENT, "--forwardlinks"},
  {"focus", CHILD, "--complement"},
  {"focus", "all", "--filter", "vextype:task", "--select", "cost"},
  {"focus", "all", "--between", "cost:1:9"},
  {"focus", "all", "--between", "due:2026-01-01:2026-12-31", count = 1},
  {"focus", "all", "--union", "none"},
  {"focus", "all", "--intersect", "all"},
  {"focus", "all", "--xor", "none"},
  {"focus", "all", "--notin", "none"},
  {"focus", "all", "--onlyin", "all"},
  {"focus", "./" .. CHILD .. ".md", count = 1},
  {"focus", "./"},
  {"focus", "all", "--interpret", "--between", "due:yesterday:next year"},
  {"focus", "all", "--groupby", "owner", "--orderby", "due:desc:cost", "--rn"},
}

local function name(row)
  local words = {}
  for _, word in ipairs(row) do table.insert(words, word) end
  local tag = row.bug or row.pending
  return "vex " .. table.concat(words, " ") .. (tag and " (" .. tag .. ")" or "")
end

describe("vex smoke test: every verb, view and focus (e2e, subprocess)", function()
  local dir

  setup(function()
    dir = helper.project()
    vex(dir, "add", "Child", "task", "here", "--cost", "5", "--benefit", "3", "--due", "2026-08-01T09:00:00")
    vex(dir, "add", "Parent", "abstract", "here", "--vextype", "abstract")
    vex(dir, "add", "Dependent", "atom", "here", "--vextype", "atom")
    vex(dir, "add", "Choose", "a", "car")
    helper.link(dir, PARENT, "children", {CHILD})
    helper.link(dir, DEPENDENT, "dependencies", {CHILD})
    local decision = dir .. "/" .. DECISION .. ".md"
    helper.write_file(decision, helper.read_file(decision):gsub("vextype: task", "vextype: decision"))
    helper.link(dir, DECISION, "options", {CHILD, DEPENDENT})
    vex(dir, "resolve", "all")
    vex(dir, "set", DEPENDENT, "--status", "doing")
  end)

  teardown(function()
    helper.rm_tmp_dir(dir)
  end)

  for _, group in ipairs({verbs, views, focuses}) do
    for _, row in ipairs(group) do
      local test = row.pending and pending or it
      test(name(row), function()
        local out = vex(dir, unpack(row))
        if row.count then
          assert.truthy(out:find("Focusing on " .. row.count .. " vex", 1, true), out)
        end
      end)
    end
  end

  it("vex init", function()
    local fresh = helper.make_tmp_dir()
    vex(fresh, "init")
    helper.rm_tmp_dir(fresh)
  end)

  local function covered(position)
    local seen = {init = true}
    for _, group in ipairs({verbs, views, focuses}) do
      for _, row in ipairs(group) do
        if row[position] then seen[row[position]] = true end
      end
    end
    return seen
  end

  it("exercises every verb that vex help lists", function()
    local seen = covered(1)
    for verb in vex(dir, "help"):gmatch("\n  (%S+)") do
      assert.truthy(seen[verb], "add a row for `vex " .. verb .. "` to smoke_spec.lua")
    end
  end)

  it("exercises every view that vex view lists", function()
    local seen = covered(3)
    for view in vex(dir, "view"):gmatch("\n%s+(%S+)") do
      assert.truthy(seen[view], "add a row for the `" .. view .. "` view to smoke_spec.lua")
    end
  end)
end)
