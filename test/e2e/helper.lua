-- Shared utilities for the e2e specs. These specs are black-box: they never
-- `require` core.*/lib.* modules, they only shell out to the real compiled
-- `src/vex` CLI as a subprocess, exactly as an end user would.

local M = {}

function M.shell_escape(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- Resolved to an absolute path (rather than trusting debug.getinfo's source
-- string, which is relative when busted loads this file via a relative
-- ROOT) because run_vex() cd's into a different directory before invoking
-- M.VEX_BIN, so a relative path would silently break.
local function this_dir()
  local raw = debug.getinfo(1, "S").source:match("^@(.+[\\/])")
  local handle = assert(io.popen("cd " .. M.shell_escape(raw) .. " && pwd"))
  local abs = handle:read("*l")
  handle:close()
  return abs .. "/"
end

-- The real CLI entrypoint (the luajit-shebang shim), not src/vex.lua
-- directly, so we exercise exactly what an end user invokes.
M.VEX_BIN = this_dir() .. "../../src/vex"

-- Where vex looks for global config and extensions. It points nowhere unless
-- a spec sets it, so the developer's real ~/.config/vex never leaks into tests.
M.vex_home = "/nonexistent/vex-home"

-- Creates a fresh, empty, unique temp directory and returns its absolute path.
function M.make_tmp_dir()
  local handle = assert(io.popen("mktemp -d 2>/dev/null"))
  local dir = handle:read("*l")
  handle:close()
  if not dir or #dir == 0 then
    error("helper.make_tmp_dir: mktemp failed to produce a directory")
  end
  return dir
end

-- Recursively removes a directory tree. Guards against being called with an
-- empty/root path.
function M.rm_tmp_dir(dir)
  if not dir or dir == "" or dir == "/" then
    error("helper.rm_tmp_dir: refusing to remove suspicious path: " .. tostring(dir))
  end
  os.execute("rm -rf " .. M.shell_escape(dir))
end

-- Strips ANSI SGR + OSC-8 hyperlink escape codes that lib/pretty.lua always
-- emits (no isatty/NO_COLOR check), so specs can assert on plain text.
function M.strip_ansi(s)
  s = s:gsub("\27%[[%d;]*m", "")
  s = s:gsub("\27%]8;;.-\27\\", "")
  return s
end

function M.trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Runs `src/vex <args>` with `cwd` as the working directory (vex has no
-- --dir/path flag; `vex init` throws a usage error if given any args at
-- all, so cd-ing into cwd in the *same* shell invocation is mandatory).
--
-- Captures stdout, stderr and the real shell exit code via `echo $? > file`
-- rather than trusting Lua's os.execute() return value directly: Lua
-- 5.1/LuaJIT's os.execute() returns the raw POSIX wait-status (exit code
-- shifted left 8 bits), not a normalised 0-255 code.
--
-- `args` is an array of argv-style strings, e.g.
-- {"add", "Make", "coffee", "--importance", "high"}
function M.run_vex(cwd, args)
  local quoted = {}
  for _, a in ipairs(args) do
    table.insert(quoted, M.shell_escape(a))
  end

  local stdout_path = cwd .. "/.e2e_stdout"
  local stderr_path = cwd .. "/.e2e_stderr"
  local exit_path   = cwd .. "/.e2e_exit"

  local cmd = string.format(
    "cd %s && VEX_HOME=%s %s %s >%s 2>%s ; echo $? > %s",
    M.shell_escape(cwd),
    M.shell_escape(M.vex_home),
    M.shell_escape(M.VEX_BIN),
    table.concat(quoted, " "),
    M.shell_escape(stdout_path),
    M.shell_escape(stderr_path),
    M.shell_escape(exit_path)
  )

  os.execute(cmd)

  local function slurp(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local content = f:read("*a")
    f:close()
    os.remove(path)
    return content
  end

  local stdout = slurp(stdout_path)
  local stderr = slurp(stderr_path)
  local exit_code = tonumber(M.trim(slurp(exit_path))) or -1

  if stderr:find("Internal error", 1, true) then
    error("vex " .. table.concat(args, " ") .. " crashed:\n" .. M.strip_ansi(stderr), 2)
  end

  return { stdout = stdout, stderr = stderr, code = exit_code }
end

function M.vex(cwd, ...)
  local args = {...}
  local result = M.run_vex(cwd, args)
  if result.code ~= 0 then
    error("vex " .. table.concat(args, " ") .. " failed:\n" .. M.strip_ansi(result.stderr), 2)
  end
  return M.trim(M.strip_ansi(result.stdout))
end

function M.vex_fails(cwd, expected, ...)
  local args = {...}
  local result = M.run_vex(cwd, args)
  local stderr = M.strip_ansi(result.stderr)
  if result.code == 0 then
    error("vex " .. table.concat(args, " ") .. " should have failed", 2)
  end
  if not stderr:find(expected, 1, true) then
    error("vex " .. table.concat(args, " ") .. " failed without '" .. expected .. "':\n" .. stderr, 2)
  end
  return stderr
end

function M.project()
  local dir = M.make_tmp_dir()
  M.vex(dir, "init")
  local config = dir .. "/.vex/config.lua"
  M.write_file(config, (M.read_file(config):gsub("  paths = {.-\n  },\n", "")))
  return dir
end

local function shell_ok(cmd)
  local result = os.execute(cmd)
  return result == true or result == 0
end

function M.is_dir(path)
  return shell_ok("test -d " .. M.shell_escape(path))
end

function M.is_file(path)
  return shell_ok("test -f " .. M.shell_escape(path))
end

function M.read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  return content
end

function M.write_file(path, content)
  local f = assert(io.open(path, "w"))
  f:write(content)
  f:close()
end

function M.copy_tree(from, to)
  assert(os.execute("mkdir -p " .. M.shell_escape(to) .. " && cp -R " .. M.shell_escape(from) .. "/. " .. M.shell_escape(to)))
end

function M.task_file(dir, vexid)
  local handle = assert(io.popen("find " .. M.shell_escape(dir) .. " -name " .. M.shell_escape(vexid .. ".md")))
  local path = handle:read("*l")
  handle:close()
  return path
end

function M.link(dir, vexid, field, targets)
  local path = assert(M.task_file(dir, vexid), "no task file for " .. vexid)
  local items = {field .. ":"}
  for _, target in ipairs(targets) do
    table.insert(items, '  - "[[' .. target .. ']]"')
  end
  local content = M.read_file(path)
    :gsub("\n" .. field .. ": %[%]\n", "\n", 1)
    :gsub("\n%-%-%-\n", "\n" .. table.concat(items, "\n") .. "\n---\n", 1)
  M.write_file(path, content)
end

local function unquote(value)
  return (value:gsub('^"(.*)"$', "%1"))
end

function M.frontmatter(path)
  local fields, last = {}, nil
  local yaml = assert(M.read_file(path), "no task file at " .. path):match("^%-%-%-\n(.-)\n%-%-%-")
  for line in (yaml .. "\n"):gmatch("(.-)\n") do
    local key, value = line:match("^([%w_]+):%s*(.-)%s*$")
    local item = line:match("^%s+%- (.-)%s*$")
    if key then
      fields[key] = (value == "" or value == "[]") and {} or unquote(value)
      last = key
    elseif item and last then
      table.insert(fields[last], unquote(item))
    end
  end
  return fields
end

return M
