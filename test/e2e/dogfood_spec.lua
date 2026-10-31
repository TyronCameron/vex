local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local vex = helper.vex

local repo = spec_dir .. "../.."

describe("this repo's own backlog (e2e, subprocess)", function()
  local dir

  setup(function()
    dir = helper.project()
    helper.write_file(dir .. "/.vex/config.lua", helper.read_file(repo .. "/.vex/config.lua"))
    for _, folder in ipairs({"tasks", "recipes", "focuses", "views"}) do
      if helper.is_dir(repo .. "/.vex/" .. folder) then
        helper.copy_tree(repo .. "/.vex/" .. folder, dir .. "/.vex/" .. folder)
      end
    end
    helper.copy_tree(repo .. "/vexdoc/vex", dir .. "/vexdoc/vex")
  end)

  teardown(function()
    helper.rm_tmp_dir(dir)
  end)

  local function snapshot()
    local handle = io.popen("cd " .. helper.shell_escape(dir) .. " && find vexdoc/vex -type f | sort | while read -r f; do echo \"$f\"; cat \"$f\"; done | cksum")
    local sum = handle:read("*a")
    handle:close()
    return sum
  end

  it("still resolves every task without changing its file", function()
    local before = snapshot()
    vex(dir, "resolve", "all")
    vex(dir, "resolve", "all", "--force")
    assert.equal(before, snapshot())
  end)

  it("still renders the whole backlog", function()
    for _, view in ipairs({"csv", "tabular", "kanban", "overview"}) do
      assert.truthy(#vex(dir, "view", "all", view) > 0, view)
    end
  end)
end)
