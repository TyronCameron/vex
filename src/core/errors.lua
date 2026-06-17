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
