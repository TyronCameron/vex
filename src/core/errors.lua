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

cli:error "no-focus" {
    function(msg)
        return "The current focus is unknown. " .. msg
    end,
    hint = "Try using `vex focus` or `vex add` to set the current focus."
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
    function(vexid, msg)
        return 'The Validation step failed during resolution for vexid ' .. tostring(vexid) .. '. ' .. tostring(msg or '')
    end,
    hint = "Ensure that data is correct and that the tasktype definitions in `config.lua` are sound."
}

cli:error 'resolution-failed-derivation' {
    function(vexid, msg)
        return 'The Derivation step failed during resolution for vexid ' .. tostring(vexid) .. '. ' .. tostring(msg or '')
    end,
    hint = "Ensure that data is correct and that the tasktype definitions in `config.lua` are sound."
}

cli:error 'resolution-failed-normalisation' {
    function(vexid, msg)
        return 'The Normalisation step failed during resolution for vexid ' .. tostring(vexid) .. '. ' .. tostring(msg or '')
    end,
    hint = "Ensure that data is correct and that the tasktype definitions in `config.lua` are sound."
}

cli:error 'resolution-failed-linking' {
    function(vexid, msg)
        return 'The Linking step failed during resolution for vexid ' .. tostring(vexid) .. '. ' .. tostring(msg or '')
    end,
    hint = "Ensure that data is correct and that the tasktype definitions in `config.lua` are sound."
}


