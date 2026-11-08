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

  local function mtime(vexid)
    local handle = io.popen("find " .. helper.shell_escape(dir .. "/" .. vexid .. ".md") .. " -printf '%T@'")
    local result = handle:read("*a")
    handle:close()
    return result
  end

  local function stamps()
    local result = snapshot()
    for vexid in pairs(snapshot()) do result[vexid .. " mtime"] = mtime(vexid) end
    return result
  end

  local function edit(vexid, from, to)
    local path = dir .. "/" .. vexid .. ".md"
    helper.write_file(path, (helper.read_file(path):gsub(from, to, 1)))
  end

  local OLD = "2020-01-01 00:00:00"

  local function backdated_project()
    linked_project()
    for vexid in pairs(snapshot()) do edit(vexid, "\nmodified: [^\n]*\n", "\nmodified: \"" .. OLD .. "\"\n") end
    vex(dir, "resolve", "all")
  end

  local function modified(vexid)
    return helper.frontmatter(dir .. "/" .. vexid .. ".md").modified
  end

  it("leaves task files untouched when resolving them again", function()
    linked_project()
    local before = stamps()
    vex(dir, "resolve", "all")
    vex(dir, "resolve", "all", "--force")
    assert.same(before, stamps())
  end)

  it("keeps a backdated modified time through resolving, as only modified changed", function()
    backdated_project()
    vex(dir, "resolve", "all", "--force")
    for vexid in pairs(snapshot()) do assert.equal(OLD, modified(vexid), vexid) end
  end)

  it("rewrites nothing when a set changes nothing", function()
    backdated_project()
    local before = stamps()
    vex(dir, "set", "child-task-here-1", "--cost", "5")
    assert.same(before, stamps())
  end)

  it("moves modified only on the task a set changes", function()
    backdated_project()
    local before = stamps()
    vex(dir, "set", "child-task-here-1", "--cost", "6")
    assert.not_equal(OLD, modified("child-task-here-1"))
    for _, vexid in ipairs({"parent-abstract-here-1", "dependent-atom-here-1"}) do
      assert.equal(before[vexid], helper.read_file(dir .. "/" .. vexid .. ".md"), vexid)
      assert.equal(before[vexid .. " mtime"], mtime(vexid), vexid)
    end
  end)

  it("writes no task file when rebuilding a lost index", function()
    linked_project()
    local before = stamps()
    os.execute("rm -rf " .. helper.shell_escape(dir .. "/.vex/vexdex"))
    vex(dir, "resolve", "all")
    assert.same(before, stamps())
  end)

  it("treats a touched but unchanged file as unchanged", function()
    backdated_project()
    os.execute("touch " .. helper.shell_escape(dir .. "/child-task-here-1.md"))
    vex(dir, "resolve", "all")
    assert.equal(OLD, modified("child-task-here-1"))
  end)

  it("reads a hand edit only once resolve takes it in, and then moves its modified", function()
    backdated_project()
    edit("child-task-here-1", "\ncost: 5\n", "\ncost: 9\n")
    assert.equal("5", vex(dir, "get", "child-task-here-1", "--cost"))
    assert.truthy(vex(dir, "focus", "all", "--filter", "cost:9"):find("Focusing on 0 vexes", 1, true))
    assert.equal(OLD, modified("child-task-here-1"))
    vex(dir, "resolve", "all")
    assert.equal("9", vex(dir, "get", "child-task-here-1", "--cost"))
    assert.not_equal(OLD, modified("child-task-here-1"))
  end)

  local function state()
    local files = {}
    local handle = io.popen("cd " .. helper.shell_escape(dir) .. " && find . -path ./.vex -prune -o -type f ! -name '.e2e_*' -printf '%p %T@\\n' | sort")
    for line in handle:lines() do
      local path = line:match("^(.-) [%d.]+$")
      files[line] = helper.read_file(dir .. "/" .. path)
    end
    handle:close()
    local vexdex = function(names)
      local result = {}
      for _, name in ipairs(names) do result[name] = helper.read_file(dir .. "/.vex/vexdex/" .. name) or "" end
      return result
    end
    return {
      taskfiles = files,
      index = vexdex({"index.bin", "backlinks.bin", "paths.bin", "fingerprints.bin", "mtimes.bin"}),
      focus = vexdex({"focus.bin"}),
    }
  end

  local function same(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
  end

  local effects = {
    {{"help"}},
    {{"version"}},
    {{"show", "child-task-here-1"}},
    {{"get", "all", "--cost"}},
    {{"view", "all", "tabular"}},
    {{"view", "all", "overview"}},
    {{"view", "child-task-here-1", "singular"}},
    {{"focus"}},
    {{"focus", "all", "--filter", "status:todo"}, focus = true},
    {{"add", "Brand", "new", "task"}, index = true, focus = true, taskfiles = true},
    {{"set", "dependent-atom-here-1", "--cost", "7"}, index = true, taskfiles = true},
    {{"resolve", "all"}, index = true, taskfiles = true},
    {{"remove", "dependent-atom-here-1"}, index = true, focus = true, taskfiles = true},
    {{"recipe", "abstract", "Brand", "new", "abstract"}, index = true, focus = true, taskfiles = true},
  }

  for _, effect in ipairs(effects) do
    local words = table.concat(effect[1], " ")
    it("changes only what the CLI reference says when running vex " .. words .. " over a hand edit", function()
      linked_project()
      vex(dir, "focus", "all")
      edit("child-task-here-1", "\ncost: 5\n", "\ncost: 9\n")
      local before = state()
      vex(dir, unpack(effect[1]))
      local after = state()
      for _, part in ipairs({"index", "focus", "taskfiles"}) do
        local changed = not same(before[part], after[part])
        assert.are.equal(effect[part] or false, changed, "vex " .. words .. (changed and " changed " or " left ") .. part)
      end
    end)
  end

  it("shows a task file as it is on disk, unresolved", function()
    linked_project()
    edit("child-task-here-1", "\ncost: 5\n", "\ncost: 9\ndue: tomorrow 8am\n")
    local out = vex(dir, "show", "child-task-here-1")
    assert.truthy(out:find("due: tomorrow 8am", 1, true), out)
    assert.truthy(out:find("cost: 9", 1, true), out)
    assert.truthy(out:find("Notes about the child", 1, true), out)
    assert.truthy(helper.read_file(dir .. "/child-task-here-1.md"):find("due: tomorrow 8am", 1, true))
  end)

  it("warns on stderr, and only there, while indexed task files changed since vex last saw them", function()
    linked_project()
    edit("child-task-here-1", "\ncost: 5\n", "\ncost: 9\n")
    for _, args in ipairs({{"get", "child-task-here-1", "--cost"}, {"view", "all", "csv"}, {"focus", "all"}}) do
      local result = helper.run_vex(dir, args)
      assert.truthy(helper.strip_ansi(result.stderr):find("1 task file changed since vex last saw it", 1, true), table.concat(args, " "))
      assert.is_nil(result.stdout:find("changed since", 1, true))
    end
    assert.equal("5", vex(dir, "get", "child-task-here-1", "--cost"))
    vex(dir, "resolve", "all")
    assert.equal("", helper.run_vex(dir, {"get", "child-task-here-1", "--cost"}).stderr)
  end)

  it("gives no warning for a new file vex has not indexed", function()
    linked_project()
    helper.write_file(dir .. "/Buy groceries.md", "---\ntitle: Buy groceries\n---\n")
    assert.equal("", helper.run_vex(dir, {"get", "all"}).stderr)
  end)

  it("writes no index when a read verb runs without one, as in a fresh clone", function()
    linked_project()
    os.execute("rm -rf " .. helper.shell_escape(dir .. "/.vex/vexdex"))
    vex(dir, "get", "all")
    assert.is_false(helper.is_file(dir .. "/.vex/vexdex/index.bin"))
  end)

  it("lists hand-edited tasks as updated, and takes in new task files on resolve all", function()
    linked_project()
    edit("child-task-here-1", "\ncost: 5\n", "\ncost: 9\n")
    helper.write_file(dir .. "/made-hand-1.md", "---\nvexid: made-hand-1\ndescription: Made by hand\nvextype: task\n---\n")
    assert.truthy(vex(dir, "focus", "updated"):find("Focusing on 1 vex", 1, true))
    vex(dir, "resolve", "all")
    assert.truthy(vex(dir, "focus", "updated"):find("Focusing on 0 vexes", 1, true))
    assert.truthy(vex(dir, "focus", "all"):find("Focusing on 4 vexes", 1, true))
  end)

  it("forgets a task whose file was deleted by hand", function()
    local vexid = vex(dir, "add", "Deleted", "by", "hand")
    vex(dir, "add", "Kept", "around", "here")
    os.remove(dir .. "/" .. vexid .. ".md")
    vex(dir, "resolve", "all")
    assert.truthy(vex(dir, "focus", "all"):find("Focusing on 1 vex", 1, true))
  end)

  it("writes a normalised value back to the file it resolves", function()
    local vexid = vex(dir, "add", "Hand", "dated", "task")
    edit(vexid, "\nstatus: todo\n", "\nstatus: todo\ndue: tomorrow 8am\n")
    vex(dir, "resolve", vexid)
    local t = os.date("*t", os.time() + 86400)
    assert.equal(string.format("%04d-%02d-%02d 08:00:00", t.year, t.month, t.day), helper.frontmatter(dir .. "/" .. vexid .. ".md").due)
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

  it("keeps fields written by other tools through a set", function()
    local vexid = vex(dir, "add", "Shared", "with", "tasknotes")
    local path = dir .. "/" .. vexid .. ".md"
    helper.write_file(path, helper.read_file(path):gsub("\nstatus: todo\n",
      '\nstatus: todo\ncontexts: [office, "home, garden"]\nblockedBy:\n  - uid: "[[other]]"\n    reltype: FINISHTOSTART\ndue: 2026-10-01T08:00:00+02:00\n'))
    vex(dir, "resolve", "all")
    vex(dir, "set", vexid, "--cost", "1")
    local content = helper.read_file(path)
    assert.truthy(content:find('contexts: \n  - office\n  - "home, garden"\n', 1, true))
    assert.truthy(content:find('blockedBy: \n  - \n    reltype: FINISHTOSTART\n    uid: "[[other]]"\n', 1, true))
    assert.truthy(content:find('\ndue: "2026-10-01 ', 1, true))
  end)

  it("ignores files in the task folder that are not readable tasks", function()
    local vexid = vex(dir, "add", "Real", "task", "here")
    helper.write_file(dir .. "/Buy groceries.md", "---\ntitle: Buy groceries\nstatus: todo\n---\n")
    helper.write_file(dir .. "/broken.md", "---\nvexid: broken-1\ndescription: never closed\n")
    vex(dir, "resolve", "all")
    assert.truthy(vex(dir, "focus", "all"):find("Focusing on 1 vex", 1, true))
    assert.truthy(vex(dir, "show", vexid):find("Real task here", 1, true))
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

  it("keeps only binary files in the vexdex besides the logs", function()
    vex(dir, "add", "Plain", "task")
    vex(dir, "focus", "all")
    local listing = helper.shell(dir, "ls .vex/vexdex")
    assert.is_nil(listing:find("%.lua"))
    assert.truthy(listing:find("index.bin", 1, true))
    assert.truthy(listing:find("focus.bin", 1, true))
  end)

  it("keeps task bodies out of the index, so only show prints them", function()
    local vexid = vex(dir, "add", "Body", "stays", "home", "--vexbody", "Window seat please")
    assert.is_nil(helper.read_file(dir .. "/.vex/vexdex/index.bin"):find("Window seat", 1, true))
    assert.equal("", vex(dir, "get", vexid, "--vexbody"))
    assert.is_nil(vex(dir, "view", vexid, "json"):find("Window seat", 1, true))
    assert.truthy(vex(dir, "show", vexid):find("Window seat please", 1, true))
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


  it("keeps the body of a task linking to a removed task (keep-body-tasks-linking-removed-1)", function()
    local dependent = vex(dir, "add", "Dependent", "task", "here", "--vexbody", "Remember the milk")
    local dependency = vex(dir, "add", "Dependency", "task", "here")
    vex(dir, "set", dependent, "--dependencies", dependency)
    vex(dir, "remove", dependency)
    assert.equal("", vex(dir, "get", dependent, "--dependencies"))
    assert.truthy(helper.read_file(dir .. "/" .. dependent .. ".md"):find("Remember the milk", 1, true))
  end)

  it("writes no task file when a verb fails on a later task", function()
    local child = vex(dir, "add", "Child", "task", "here", "--vextype", "atom")
    local abstract = vex(dir, "add", "Alpha", "abstract", "here", "--vextype", "abstract")
    local atom = vex(dir, "add", "Zulu", "atom", "here", "--vextype", "atom")
    local before = helper.read_file(dir .. "/" .. abstract .. ".md")
    helper.vex_fails(dir, "Expected no value", "set", abstract .. "," .. atom, "--children", child)
    assert.are.equal(before, helper.read_file(dir .. "/" .. abstract .. ".md"))
    assert.are.equal("", vex(dir, "get", abstract, "--children"))
  end)

  it("keeps quotes and backslashes in a description through repeated resolves (fix-descriptions-quotes-gaining-1)", function()
    local description = 'Say "hi" to C:\\dir, then leave'
    local vexid = vex(dir, "add", description)
    vex(dir, "resolve", "all")
    vex(dir, "resolve", "all")
    local json = vex(dir, "view", vexid, "json")
    assert.truthy(json:find('"description": "Say \\"hi\\" to C:\\\\dir, then leave"', 1, true), json)
  end)
end)
