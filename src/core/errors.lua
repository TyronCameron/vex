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
    function(focusname)
        return "You are attempting to create an unknown focus with name: " .. tostring(focusname)
    end,
    hint = "Use one of the standard focus names ('all', 'none', 'prev') or a valid vexid which is in the vexdex. Use vex resolve all if your vexdex is out of date."
}

cli:error "unknown-focus-operation" {
    function(operation)
        return 'Unknown focus operation `' .. tostring(operation) .. '`.'
    end,
    hint = "Use a focus flag such as `--select`, `--filter`, `--orderby` or `--groupby`. See `vex help focus`."
}

cli:error "uninterpretable" {
    function(value, field)
        return 'Cannot interpret `' .. tostring(value) .. '` as a value of `' .. tostring(field) .. '`.'
    end,
    hint = "Use a phrase such as `tomorrow`, `next tuesday`, `friday arvo`, `in 3 days`, `26 July` or `2026-07-26 09:00`."
}

cli:error "missing-required-field" {
    function(vexid, field)
        return "A required field is missing from a task. Vexid = " .. tostring(vexid) .. ', field = ' .. tostring(field)
    end,
    hint = "Ensure that all tasks have all required fields, such as: `vexid`, `vextype`, `description`, `status`, `created`, and `modified`"
}

cli:error "unknown-vextype" {
    function(vextype, all_types)
        if type(all_types) ~= "table" then all_types = {} end 
        return "The vextype for this vex task is unknown. Type  = " .. tostring(vextype) .. '. Available types = ' .. table.concat(all_types, ',')
    end,
    hint = "Ensure that the vextype is correctly written in your `config.lua` file and that this vex task has a matching name."
}

cli:error 'resolution-failed-validation' {
    function(vexid, msg, undermsg)
        return table.concat({
            'The validation step failed during resolution for vexid `' .. (vexid and tostring(vexid)) .. '`',
            msg and tostring(msg) or '',
            undermsg and tostring(undermsg) or ''
        }, '.\n')
    end,
    hint = "Ensure that data is correct and that the tasktype definitions in `config.lua` are sound."
}

cli:error 'resolution-failed-derivation' {
    function(vexid, msg, undermsg)
        return table.concat({
            'The derivation step failed during resolution for vexid `' .. (vexid and tostring(vexid)) .. '`',
            msg and tostring(msg) or '',
            undermsg and tostring(undermsg) or ''
        }, '.\n')
    end,
    hint = "Ensure that data is correct and that the tasktype definitions in `config.lua` are sound."
}

cli:error 'resolution-failed-normalisation' {
    function(vexid, msg, undermsg)
        return table.concat({
            'The normalisation step failed during resolution for vexid `' .. (vexid and tostring(vexid)) .. '`',
            msg and tostring(msg) or '',
            undermsg and tostring(undermsg) or ''
        }, '.\n')
    end,
    hint = "Ensure that data is correct and that the tasktype definitions in `config.lua` are sound."
}

cli:error 'resolution-failed-linking' {
    function(vexid, msg)
        return 'The Linking step failed during resolution for vexid ' .. tostring(vexid) .. '. ' .. tostring(msg or '')
    end,
    hint = "Ensure that data is correct and that the tasktype definitions in `config.lua` are sound."
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

cli:error 'dependency-with-children' {
    function(vexid, dependency)
        return 'Task `' .. tostring(vexid) .. '` cannot depend on `' .. tostring(dependency) .. '`, because one of them has children.'
    end,
    hint = "Only tasks without children can take part in dependencies. Depend on the atoms under an abstract instead."
}

cli:error "unknown-view" {
    function(viewname)
        return 'A view of name `' .. tostring(viewname) .. '` does not exist.'
    end,
    hint = "Ensure that this view is correctly written in your `config.lua` file."
}

cli:error "unknown-recipe" {
    function(recipe)
        return 'A recipe of name `' .. tostring(recipe) .. '` does not exist.'
    end,
    hint = "Ensure that this recipe is correctly written in your `config.lua` file."
}

cli:error "unknown-field" {
    function(field)
        return 'A field of name `' .. tostring(field) .. '` does not exist.'
    end,
    hint = "Ensure that this field is correctly written in your `config.lua` file."
}

cli:error "task-creation-failed" {
    function(msg)
        return 'Cannot create task. Reason: ' .. tostring(msg)
    end,
    hint = "Ensure that you are calling the task adding function correctly."
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
    hint = "Put `--insert` or `--remove` before a list field, e.g. `vex set my-task --insert --children a,b`."
}
