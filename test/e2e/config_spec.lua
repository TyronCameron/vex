local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex, fails = helper.vex, helper.vex_fails

describe("vex config (e2e, subprocess)", function()
  local dir

  before_each(function()
    dir = helper.project()
  end)

  after_each(function()
    helper.rm_tmp_dir(dir)
  end)

  local function config(code, where)
    helper.write_file((where or dir) .. "/.vex/config.lua", code)
  end

  describe("task folder", function()
    local spellings = {
      {"a trailing slash", "x/tasks/"},
      {"a leading dot and doubled slashes", "./x//tasks"},
      {"backslashes", "x\\tasks"},
    }
    for _, case in ipairs(spellings) do
      it("is normalised when written with " .. case[1], function()
        config("return { taskfolder = [[" .. case[2] .. "]], paths = { groupby = {'status', 'lineage'} } }")
        vex(dir, "add", "Make", "seed", "data", "--vextype", "abstract")
        local parent = "make-seed-data-1"
        local child = vex(dir, "add", "Make", "seeding", "reproducible", "--vextype", "atom", "--parent", parent)
        vex(dir, "resolve", "all")
        vex(dir, "resolve", "all", "--force")
        assert.equal(dir .. "/x/tasks/todo/" .. parent .. "/" .. child .. ".md", helper.task_file(dir, child))
      end)
    end

    it("is read as relative to the project, so an absolute one is refused", function()
      config("return { taskfolder = '/tmp' }")
      fails(dir, "A setting in your config is wrong", "resolve", "all")
    end)
  end)

  describe("validation", function()
    it("refuses a setting of the wrong kind, naming it", function()
      config("return { loglimit = 'lots' }")
      fails(dir, "loglimit", "resolve", "all")
    end)

    it("refuses a config file that does not run, naming it", function()
      config("return {")
      fails(dir, ".vex/config.lua", "resolve", "all")
      fails(dir, "Could not read the config file", "resolve", "all")
    end)

    it("refuses a config file that does not return a table", function()
      config("return 5")
      fails(dir, "must return a table", "resolve", "all")
    end)

    it("runs with no config settings at all, grouping task files by status", function()
      config("return {}")
      local vexid = vex(dir, "add", "Plain", "task", "here")
      assert.equal(dir .. "/todo/" .. vexid .. ".md", helper.task_file(dir, vexid))
    end)
  end)

  describe("plugins", function()
    it("swaps a slot's member for a project plugin", function()
      helper.write_file(dir .. "/.vex/plugin/shorttag.lua", [[
        return { generate = function(_, lookup)
          local n = 1
          while lookup['short-' .. n] do n = n + 1 end
          return 'short-' .. n
        end }
      ]])
      config("return { plugins = { tagger = 'shorttag' } }")
      assert.equal("short-1", vex(dir, "add", "Anything", "at", "all"))
    end)

    it("switches a standalone plugin off", function()
      assert.truthy(helper.run_vex(dir, {"autocomplete", "bash"}).stdout:find("complete", 1, true))
      config("return { plugins = { vexcomplete = false } }")
      fails(dir, "unknown verb 'autocomplete'", "autocomplete", "bash")
    end)

    it("refuses a plugin or slot that does not exist", function()
      config("return { plugins = { nosuch = false } }")
      fails(dir, "nosuch", "resolve", "all")
    end)

    it("refuses a slot given a plugin that does not exist", function()
      config("return { plugins = { tagger = 'nosuch' } }")
      fails(dir, "unknown plugin 'nosuch'", "resolve", "all")
    end)

    it("takes the vexations task types away when vexations is switched off, leaving plain tasks", function()
      config("return { plugins = { vexations = false } }")
      assert.truthy(vex(dir, "add", "Plain", "task", "here"))
      assert.are_not.equal(0, helper.run_vex(dir, {"add", "An", "atom", "here", "--vextype", "atom"}).code)
    end)
  end)
end)
