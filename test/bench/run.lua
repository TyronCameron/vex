local bench_dir = debug.getinfo(1, "S").source:match("^@(.+[\\/])") or "./"
package.path = bench_dir .. "../e2e/?.lua;" .. package.path
local helper = require 'helper'
local ffi = require 'ffi'

io.stdout:setvbuf('line')

ffi.cdef [[
  typedef struct { long tv_sec; long tv_usec; } timeval;
  int gettimeofday(timeval *tv, void *tz);
]]

local function now()
  local tv = ffi.new("timeval")
  ffi.C.gettimeofday(tv, nil)
  return tonumber(tv.tv_sec) + tonumber(tv.tv_usec) / 1e6
end

local total = tonumber(os.getenv("VEX_BENCH_TASKS")) or 1000
local layers = 10
local abstracts = math.max(layers, math.floor(total / 10))
local atoms = total - abstracts
local layersize = math.ceil(atoms / layers)

local function atom(i) return "atom-" .. i .. "-1" end
local function group(i) return "group-" .. i .. "-1" end

-- atoms in 10 layers, each depending on 3 atoms of the layer before; every layer-2 atom also depends on the hub
local function dependencies(i)
  local layer = math.floor((i - 1) / layersize)
  if layer == 0 then return {} end
  local start, offset = (layer - 1) * layersize, (i - 1) % layersize
  local deps = {}
  for k = 0, 2 do table.insert(deps, atom(start + (offset + k) % layersize + 1)) end
  if layer == 1 and offset > 0 and offset < layersize - 2 then table.insert(deps, atom(1)) end
  return deps
end

-- abstracts in 10 levels: one root, the rest spread evenly over the levels below it
local function levels()
  local result, nextid = {{1}}, 2
  local rest = abstracts - 1
  for level = 2, layers do
    local count = math.floor(rest / (layers - level + 1))
    rest = rest - count
    result[level] = {}
    for _ = 1, count do
      table.insert(result[level], nextid)
      nextid = nextid + 1
    end
  end
  return result
end

local function children(tree, level, index)
  local count, kids = #tree[level], {}
  if level == layers then
    for i = index, atoms, count do table.insert(kids, atom(i)) end
  else
    for i = index, #tree[level + 1], count do table.insert(kids, group(tree[level + 1][i])) end
  end
  return kids
end

local results = {}

local function record(step, seconds)
  table.insert(results, {step, seconds})
  print(string.format("%-48s %8.2fs", step, seconds))
end

local function timed(step, dir, ...)
  local start = now()
  helper.vex(dir, ...)
  record(step, now() - start)
end

local function add(dir, description, vextype, field, links)
  local args = {"add", description, "--vextype", vextype}
  if #links > 0 then
    table.insert(args, "--" .. field)
    table.insert(args, table.concat(links, ","))
  end
  helper.vex(dir, unpack(args))
end

local dir = helper.make_tmp_dir()
helper.vex(dir, "init")

print(string.format("Creating %d tasks: %d atoms in %d dependency layers, %d abstracts in %d levels", total, atoms, layers, abstracts, layers))
local step = math.max(1, math.floor(total / 10))
local created, start, last, lastcount = 0, now(), now(), 0
local function progress()
  created = created + 1
  if created % step == 0 or created == total then
    local t = now()
    print(string.format("  %6d tasks  %8.2fs total  %6.3fs per add", created, t - start, (t - last) / (created - lastcount)))
    last, lastcount = t, created
  end
end

for i = 1, atoms do
  add(dir, "Atom " .. i, "atom", "dependencies", dependencies(i))
  progress()
end
local tree = levels()
for level = layers, 1, -1 do
  for index, id in ipairs(tree[level]) do
    add(dir, "Group " .. id, "abstract", "children", children(tree, level, index))
    progress()
  end
end
record(string.format("create %d tasks with vex add", total), now() - start)

timed("vex resolve all", dir, "resolve", "all")
timed("vex set atom-1-1 (hub) --due tomorrow", dir, "set", atom(1), "--due", "tomorrow")
timed("vex add (no links)", dir, "add", "Unlinked atom", "--vextype", "atom")
timed("vex add (depends on hub)", dir, "add", "Hub dependent atom", "--vextype", "atom", "--dependencies", atom(1))
timed("vex view all csv", dir, "view", "all", "csv")

helper.rm_tmp_dir(dir)

local lines = {
  string.format("### vex benchmark: %d tasks", total),
  "",
  "| step | seconds |",
  "| --- | ---: |",
}
for _, result in ipairs(results) do
  table.insert(lines, string.format("| %s | %.2f |", result[1], result[2]))
end
local summary = os.getenv("GITHUB_STEP_SUMMARY")
if summary and summary ~= "" then
  local f = assert(io.open(summary, "a"))
  f:write(table.concat(lines, "\n"), "\n")
  f:close()
end
print("\n" .. table.concat(lines, "\n"))
