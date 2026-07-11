-- Test file for core/errors.lua
local busted = require 'busted'
local cli = require 'lib.cli'
require 'core.errors'  -- registers error types as side effects

describe("errors", function()

    it("registers all expected error types on the cli singleton", function()
        local expected = {
            'already-vexed', 'not-vexed', 'unimplemented', 'file', 'write',
            'task-already-exists', 'path-already-exists', 'no-focus', 'unknown-focus',
            'missing-required-field', 'unknown-vextype',
            'resolution-failed-validation', 'resolution-failed-derivation',
            'resolution-failed-normalisation', 'resolution-failed-linking',
            'unknown-view', 'unknown-recipe', 'unknown-field', 'task-creation-failed',
        }
        for _, name in ipairs(expected) do
            assert.truthy(cli.errors[name], name .. " should be registered")
        end
    end)

    it("`file` error message includes the filename", function()
        local handler = cli.errors['file'][1]
        local msg = handler("missing.txt")
        assert.truthy(msg:find("missing.txt"))
    end)

    it("`task-already-exists` error message includes the vexid", function()
        local handler = cli.errors['task-already-exists'][1]
        local msg = handler("my-task-1")
        assert.truthy(msg:find("my%-task%-1"))
    end)

    it("`missing-required-field` error message includes both vexid and field", function()
        local handler = cli.errors['missing-required-field'][1]
        local msg = handler("my-task-1", "status")
        assert.truthy(msg:find("my%-task%-1"))
        assert.truthy(msg:find("status"))
    end)

    it("`unknown-view` error message includes the view name", function()
        local handler = cli.errors['unknown-view'][1]
        local msg = handler("kanban")
        assert.truthy(msg:find("kanban"))
    end)

    it("`resolution-failed-validation` error includes the vexid", function()
        local handler = cli.errors['resolution-failed-validation'][1]
        local msg = handler("my-task-1", "bad data")
        assert.truthy(msg:find("my%-task%-1"))
    end)

end)
