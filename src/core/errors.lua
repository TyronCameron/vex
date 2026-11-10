local cli = require "lib.cli"
local pretty = require 'lib.pretty'

cli:error "already-vexed" {
    function(msg)
        return "Already in a vex directory."
    end,
    hint = "Did you mean to write `vex init` in a different folder?"
}

cli:error "not-vexed" {
    function(msg)
        return "Not in a vex directory."
    end,
    hint = "Did you mean to write `vex init` first?"
}

cli:error "hook-failed" {
    function(event, hook, err)
        return "Event hook '" .. tostring(hook) .. "' failed on '" .. tostring(event) .. "': " .. tostring(err)
    end,
    hint = "This came from a hook in .vex/events, not from vex itself."
}

cli:error "unimplemented" {
    function(msg)
        return "CLI command not currently implemented."
    end,
    hint = "Be patient?"
}

cli:error "file" {
    function(msg)
        return "Cannot access file: " .. msg
    end,
    hint = "Check that the file exists and is not in use?"
}

cli:error "move-failed" {
    function(vexid, from, to, err)
        return 'Could not move the task file for `' .. tostring(vexid) .. '` from `' .. tostring(from) .. '` to `' .. tostring(to) .. '`: ' .. tostring(err)
    end,
    hint = "Check that the folder is writable and that nothing else holds the file open."
}

cli:error "duplicate-vexid" {
    function(vexid, first, second)
        return 'The vexid `' .. tostring(vexid) .. '` is held by two files: `' .. tostring(first) .. '` and `' .. tostring(second) .. '`.'
    end,
    hint = "Keep one of the files. Nothing was changed."
}

cli:error "bad-config" {
    function(failure)
        return 'A setting in your config is wrong: ' .. tostring(failure)
    end,
    hint = "Fix it in `.vex/config.lua`, in a `.vex/config.lua` further up the folder tree, or in the global `config.lua`."
}

cli:error "bad-config-file" {
    function(path, err)
        return 'Could not read the config file `' .. tostring(path) .. '`: ' .. tostring(err)
    end,
    hint = "A config file must be valid Lua that returns a table, e.g. `return { taskfolder = 'tasks' }`."
}

cli:error "bad-plugin-setting" {
    function(name, problem)
        return 'The `plugins` setting in your config is wrong at `' .. tostring(name) .. '`: ' .. tostring(problem)
    end,
    hint = "Write `plugins = { slot = 'member' }` to choose what fills a slot, or `plugins = { name = false }` to turn a plugin off. Plugins come from `src/plugin` and from the `plugin` folder of `.vex` and the global folder."
}

cli:error "bad-groupby" {
    function(groupby)
        return 'The `paths.groupby` setting in your config must be a list of field names, but it is `' .. tostring(groupby) .. '`.'
    end,
    hint = "Write it as a list, e.g. `paths = { groupby = {'lineage', 'status'} }`, or remove it to keep task files flat."
}

cli:error "write" {
    function(path, vexpath)
        return 'Could not write file intended for `' .. tostring(path) .. '`. This may be partially written to `' .. tostring(vexpath) .. '`.'
    end,
    hint = "This could be an error in a function rather than a write failure itself. Worth checking both possibilities."
}

cli:error "task-already-exists" {
    function(msg, path)
        local str = "Cannot create a new task; task vexid already exists: " .. msg
        if path then 
            str = str .. " at path " .. path
        end 
        return str
    end,
    hint = "You may be trying to create the same task twice?"
}

cli:error "path-already-exists" {
    function(path)
        local str = "Cannot create a new task here; the path already exists: " .. tostring(path)
        return str
    end,
    hint = "Possibly something has gone wrong with the structuring of files?"
}


cli:error "no-focus" {
    function(msg)
        return "The current focus is unknown. " .. msg
    end,
    hint = "Try using `vex focus` or `vex add` to set the current focus."
}

cli:error "unknown-focus" {
    function(focusname, suggestions)
        local message = "No task or focus called `" .. tostring(focusname) .. "`."
        if type(suggestions) == "table" and #suggestions > 0 then
            message = message .. " Did you mean `" .. table.concat(suggestions, "`, `") .. "`?"
        end
        return message
    end,
    hint = "Use a vexid, a task file or folder, or a named focus such as `all`, `prev`, `ready` or `final`. Run `vex resolve all` if the task file is new."
}

cli:error "unknown-focus-operation" {
    function(operation)
        return 'Unknown focus operation `' .. tostring(operation) .. '`.'
    end,
    hint = "Use a focus flag such as `--select`, `--filter`, `--orderby` or `--groupby`. See `vex help focus`."
}

cli:error "bad-autotags" {
    function(entry)
        return 'The `autotags` setting in your config must map tag names to functions, but `' .. tostring(entry) .. '` is not one.'
    end,
    hint = "Write each rule as a tag name without spaces and a function of the task, e.g. `autotags = { done = function(t) return t.phase == 'final' end }`."
}

cli:error "tag-rule-failed" {
    function(tag, vexid, err)
        return 'The rule for the tag `' .. tostring(tag) .. '` failed on `' .. tostring(vexid) .. '`: ' .. tostring(err)
    end,
    hint = "Fix the rule in the `autotags` setting of your config. A rule gets the task and returns whether the tag applies."
}

cli:error "bad-match" {
    function(pattern)
        return 'Bad pattern `' .. tostring(pattern) .. '`.'
    end,
    hint = "`--match` takes a Lua pattern, such as `^Fix.*$`. Escape magic characters with `%`."
}

cli:error "uninterpretable" {
    function(field, failure)
        return tostring(failure) .. '\n\n' .. pretty.string('while interpreting `' .. tostring(field) .. '`', 'dim')
    end
}

cli:error "not-a-date-field" {
    function(field)
        return 'The field `' .. tostring(field) .. '` is not a date or datetime.'
    end,
    hint = "Pick a date field with `--by`, such as `due` or `created`."
}

cli:error "missing-required-field" {
    function(vexid, field)
        return "Task `" .. tostring(vexid) .. "` has no `" .. tostring(field) .. "`."
    end,
    hint = "Add the field to the task file. Every task file needs a `vexid`, a `vextype` and a `description`."
}

cli:error "unknown-vextype" {
    function(vextype, all_types)
        return "Unknown task type `" .. tostring(vextype) .. "`. The types are " .. table.concat(type(all_types) == "table" and all_types or {}, ', ') .. "."
    end,
    hint = "Check the spelling, or add the type in `.vex/tasks`."
}

local function resolutionfailure(step)
    return function(vexid, failure, path)
        local footer = pretty.string('the ' .. step .. ' step failed while resolving ', 'dim') .. '`' .. tostring(vexid) .. '`'
        if path then footer = footer .. pretty.string(' in ', 'dim') .. pretty.string(path, {filelink = path}) end
        return failure and (tostring(failure) .. '\n\n' .. footer) or footer
    end
end

cli:error 'resolution-failed-validation' {
    resolutionfailure('validation'),
    hint = "Fix the value, or the task file if you edited it by hand. Task types are defined in `.vex/tasks`."
}

cli:error 'resolution-failed-derivation' {
    resolutionfailure('derivation'),
    hint = "Fix the value, or the task file if you edited it by hand. Task types are defined in `.vex/tasks`."
}

cli:error 'resolution-failed-normalisation' {
    resolutionfailure('normalisation'),
    hint = "Fix the value, or the task file if you edited it by hand. Task types are defined in `.vex/tasks`."
}

cli:error 'resolution-failed-linking' {
    function(vexid, msg)
        return 'The Linking step failed during resolution for vexid ' .. tostring(vexid) .. '. ' .. tostring(msg or '')
    end,
    hint = "Fix the value, or the task file if you edited it by hand. Task types are defined in `.vex/tasks`."
}

cli:error 'multiple-parents' {
    function(vexid, parent, otherparent)
        return 'Task `' .. tostring(vexid) .. '` cannot be a child of both `' .. tostring(parent) .. '` and `' .. tostring(otherparent) .. '`.'
    end,
    hint = "A task may appear in at most one abstract's `children`. Remove it from one of them."
}

cli:error 'self-child' {
    function(vexid)
        return 'Task `' .. tostring(vexid) .. '` cannot be a child of itself.'
    end,
    hint = "Remove the task from its own `children`."
}

cli:error 'immutable-vexid' {
    function(vexid)
        return 'The vexid of `' .. tostring(vexid) .. '` cannot be changed.'
    end,
    hint = "A vexid is a task's identity and filename. Add a new task instead, then remove this one."
}

cli:error 'dependency-cycle' {
    function(vexid, dependency)
        return 'Task `' .. tostring(vexid) .. '` cannot depend on `' .. tostring(dependency) .. '`, which already depends on it directly or indirectly.'
    end,
    hint = "Dependencies must not form a cycle. Remove one of the dependencies."
}

cli:error 'due-out-of-order' {
    function(vexid, dependency)
        return 'Task `' .. tostring(vexid) .. '` is due earlier than `' .. tostring(dependency) .. '`, which it depends on.'
    end,
    hint = "A task must be due no earlier than the tasks it depends on. Change one of the due dates."
}

cli:error 'blocked' {
    function(vexid, status, dependency)
        return 'Task `' .. tostring(vexid) .. '` can\'t move to `' .. tostring(status) .. '` while `' .. tostring(dependency) .. '`, which it depends on, isn\'t finished.'
    end,
    hint = "Finish the tasks it depends on first, or drop the dependency with `vex set <vexid> --remove --dependencies <dependency>`."
}

cli:error 'dependency-with-children' {
    function(vexid, dependency)
        return 'Task `' .. tostring(vexid) .. '` cannot depend on `' .. tostring(dependency) .. '`, because it has children or options.'
    end,
    hint = "Depend on the atoms under an abstract, or on the option a decision chose, instead."
}

cli:error "unknown-view" {
    function(viewname)
        return 'A view of name `' .. tostring(viewname) .. '` does not exist.'
    end,
    hint = "Run `vex view` to list the views, and add your own in `.vex/views`. Given one word, `vex view` takes it as the view: write `vex view all tabular`, not `vex view all`."
}

cli:error "unknown-recipe" {
    function(recipe)
        return 'A recipe of name `' .. tostring(recipe) .. '` does not exist.'
    end,
    hint = "Run `vex recipe` to list the recipes. Add your own in `.vex/recipes`."
}

cli:error "unknown-field" {
    function(field)
        return 'A field of name `' .. tostring(field) .. '` does not exist.'
    end,
    hint = "Check the spelling. A task type's fields are defined in `.vex/tasks`."
}

cli:error "recipe-needs-flag" {
    function(recipe, flag, meaning)
        return 'The `' .. tostring(recipe) .. '` recipe needs `--' .. tostring(flag) .. '`: ' .. tostring(meaning) .. '.'
    end,
    hint = "Run e.g. `vex recipe recurring Do dishes --start today --recur weekly` or `vex recipe repeat Do dishes --n 10`."
}

cli:error "task-creation-failed" {
    function(msg)
        return tostring(msg)
    end,
    hint = "Describe the task in a few words, e.g. `vex add Make coffee`."
}

cli:error "bad-extension" {
    function(path, err)
        return 'Could not load the vex extension at `' .. tostring(path) .. '`: ' .. tostring(err)
    end,
    hint = "Fix or remove this file in your `.vex` folder."
}

cli:error "unknown-modifier" {
    function(modifier)
        return 'Unknown modifier `' .. tostring(modifier) .. '`.'
    end,
    hint = "Put `--insert` or `--remove` before a list field, e.g. `vex set my-task --insert --children a,b`, or `--clear` before any field to unset it."
}

cli:error "clear-with-value" {
    function(field)
        return 'The field `' .. tostring(field) .. '` was both cleared and given a value.'
    end,
    hint = "Use `--clear --field` alone to unset it, or drop `--clear` to set a new value."
}

cli:error "missing-value" {
    function(field)
        return 'The flag `--' .. tostring(field) .. '` needs a value.'
    end,
    hint = "Give it one, e.g. `vex set my-task --status done`, or put `--clear` before it to unset the field."
}
