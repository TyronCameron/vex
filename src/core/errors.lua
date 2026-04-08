local cli = require "lib.cli"

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