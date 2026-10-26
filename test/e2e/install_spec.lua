local spec_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
package.path = spec_dir .. "?.lua;" .. package.path
local helper = require 'helper'
local esc = helper.shell_escape

local repo = spec_dir .. "../../"

local function sh(cmd)
  local handle = assert(io.popen(cmd .. " 2>&1; echo \"exit:$?\""))
  local out = handle:read("*a")
  handle:close()
  local code = tonumber(out:match("exit:(%d+)%s*$"))
  return code == 0, (out:gsub("exit:%d+%s*$", ""))
end

local function ok(cmd)
  local passed, out = sh(cmd)
  assert(passed, cmd .. " failed:\n" .. out)
  return helper.trim(out)
end

describe("installing vex (e2e, subprocess)", function()
  local prefix, work

  before_each(function()
    prefix = helper.make_tmp_dir()
    work = helper.make_tmp_dir()
  end)

  after_each(function()
    helper.rm_tmp_dir(prefix)
    helper.rm_tmp_dir(work)
  end)

  local function installed(args)
    return "cd " .. esc(work) .. " && VEX_HOME=/nonexistent/vex-home " .. esc(prefix .. "/bin/vex") .. " " .. args
  end

  local function install(dir, extra)
    return "cd " .. esc(dir) .. " && PREFIX=" .. esc(prefix) .. " sh install.sh " .. (extra or "")
  end

  it("puts a working vex on the prefix from the repository", function()
    ok(install(repo))
    ok(installed("init"))
    assert.equal("write-readme-1", ok(installed("add Write readme")))
    assert.truthy(ok(installed("view all tabular")):find("write-readme-1", 1, true))
  end)

  it("reports the version it was packaged with", function()
    ok("bash " .. esc(repo .. "scripts/package.sh") .. " 9.8.7 " .. esc(work .. "/dist"))
    ok("mkdir " .. esc(work .. "/unpacked") .. " && tar -xzf " .. esc(work .. "/dist/vex-9.8.7.tar.gz") .. " -C " .. esc(work .. "/unpacked"))
    ok(install(work .. "/unpacked/vex-9.8.7"))
    assert.equal("9.8.7", ok(installed("version")))
    ok("cd " .. esc(work .. "/dist") .. " && sha256sum -c SHA256SUMS")
    ok("test -f " .. esc(work .. "/dist/vex-9.8.7.zip"))
  end)

  it("replaces the previous install on upgrade", function()
    ok(install(repo))
    ok("touch " .. esc(prefix .. "/lib/vex/stale.lua"))
    ok(install(repo))
    assert.is_false((sh("test -e " .. esc(prefix .. "/lib/vex/stale.lua"))))
  end)

  it("removes everything it installed", function()
    ok(install(repo))
    ok(install(repo, "--uninstall"))
    assert.is_false((sh("test -e " .. esc(prefix .. "/bin/vex"))))
    assert.is_false((sh("test -e " .. esc(prefix .. "/lib/vex"))))
  end)
end)
