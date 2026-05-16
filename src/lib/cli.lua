local func = require 'lib.func'

-- ---------------------------------------------------------------------------
-- Arguments
-- ---------------------------------------------------------------------------

local Arguments = {}
Arguments.__index = Arguments

function Arguments:flags()
    local taskproperties = {}
    local argproperties = func.ifilter(self, function(word) return type(word) == "table" end)
    for _, pair in ipairs(argproperties) do
        if pair[2] then 
            taskproperties[pair[1]] = pair[2]
        end 
    end
    return taskproperties
end 

function Arguments:positional()
    return func.ifilter(self, function(word) return type(word) == "string" end)
end 

-- ---------------------------------------------------------------------------
-- CLI
-- ---------------------------------------------------------------------------

local CLI = {}
CLI.__index = CLI

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

local function parse_args(txt)
    -- splits a string into positional args and named flags
    -- "query tag --filter --select a --drop b" => {"query", "tag", {"filter"}, {"select","a"}, {"drop", "b"}}
    local args = {}
    local i = 1
    local tokens = {}
    for token in txt:gmatch("%S+") do
        table.insert(tokens, token)
    end
    while i <= #tokens do
        local t = tokens[i]
        if t:sub(1, 2) == "--" then
            local key = t:sub(3)
            local val = tokens[i + 1]
            if val and val:sub(1, 2) ~= "--" then
                table.insert(args, {key, val})
                i = i + 2
            else
                table.insert(args, {key})
                i = i + 1
            end
        else
            table.insert(args, t)
            i = i + 1
        end
    end
    return setmetatable(args, Arguments)
end

local function validate_normalise_verb(verbname, tab)
    assert(type(tab[1]) == "function",
        "Cannot register '" .. verbname .. "': table must have a function at position 1")
    assert(tab.doc,
        "Cannot register '" .. verbname .. "': missing required 'doc' field")
    return {
        tab[1],
        doc     = tab.doc,
        args    = tab.args    or "",
        example = tab.example or "",
    }
end

-- ---------------------------------------------------------------------------
-- Built-in verb/error factories
-- ---------------------------------------------------------------------------

local function create_help_verb(cli)
    return {
        function(args)
            local target = args[1]
            if target and cli.verbs[target] then
                -- detailed help for a specific verb
                local v = cli.verbs[target]
                print(cli.entrypoint .. " " .. target .. " -- " .. v.doc)
                if v.args    ~= "" then print("  args:    " .. v.args)    end
                if v.example ~= "" then print("  example: " .. v.example) end
            else
                -- general listing, padded
                local verb_names = {}
                for name in pairs(cli.verbs) do
                    table.insert(verb_names, name)
                end
                table.sort(verb_names)

                local width = 0
                for _, name in ipairs(verb_names) do
                    width = math.max(width, #name)
                end
                print("Usage: " .. cli.entrypoint .. " <verb> [args]")
                print("")
                for _, name in ipairs(verb_names) do
                    local v = cli.verbs[name]
                    local pad = string.rep(" ", width - #name + 2)
                    print("  " .. name .. pad .. v.doc)
                end
            end
        end,
        doc     = "Print help. Pass a verb name for detailed help.",
        args    = "[verb]",
        example = cli.entrypoint .. " help add",
    }
end

local function create_usage_error(cli)
    return {
        function(msg)
            local verb = cli.verbstack[#cli.verbstack] or ""
            local command = cli.verbstack[#cli.verbstack] and cli.entrypoint .. " " .. verb or cli.entrypoint
            local lines = {
                "Usage error in '" .. command .. "'",
            }
            if msg then
                table.insert(lines, "  " .. msg)
            end
            table.insert(lines, "  hint: run `" .. cli.entrypoint .. " help " .. verb .. "` for usage")
            return table.concat(lines, "\n")
        end
    }
end

local function create_bug_error(cli)
    return {
        function(msg, trace)
            local verb = cli.verbstack[#cli.verbstack] or ""
            local command = cli.verbstack[#cli.verbstack] and cli.entrypoint .. " " .. verb or cli.entrypoint
            local lines = {
                "Internal error in '" .. verb .. "'",
            }
            if msg then
                table.insert(lines, "  " .. tostring(msg))
            end
            if trace then
                table.insert(lines, trace)
            end
            return table.concat(lines, "\n")
        end,
        hint = "This is an internal error that the developers did not expect ..."
    }
end

-- ---------------------------------------------------------------------------
-- Constructor
-- ---------------------------------------------------------------------------

function CLI.new(entrypoint)
    assert(type(entrypoint) == "string" and entrypoint ~= "",
        "CLI.new requires a non-empty entrypoint string")
    local this = setmetatable({}, CLI)
    this.entrypoint  = entrypoint
    this.verbstack   = {}
    this.verbs       = {
        help = create_help_verb(this),
    }
    this.errors      = {
        usage = create_usage_error(this),
        bug   = create_bug_error(this),
    }
    return this
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- registers a verb
function CLI:verb(verbname)
    assert(type(verbname) == "string", "verb name must be a string")
    return function(tab)
        self.verbs[verbname] = validate_normalise_verb(verbname, tab)
    end
end

-- Register a custom error type. The handler receives (msg, trace).
function CLI:error(errtype)
    assert(type(errtype) == "string", "error type must be a string")
    return function(tab)
        self.errors[errtype] = tab
    end
end

-- Run from a raw arg string (or pass arg table directly).
function CLI:run(input)
    local args
    if type(input) == "string" then
        args = parse_args(input)
    elseif type(input) == "table" then
        args = setmetatable(input, Arguments)
    else
        self:throw("usage", "run() expects a string or arg table")
    end

    local verbname = table.remove(args, 1)
    if not verbname then
        self:throw("usage", "no verb provided")
    end
    if not self.verbs[verbname] then
        self:throw("usage", "unknown verb '" .. verbname .. "'")
    end

    local result = self:call(verbname, args)
    if result and type(result) == "string" or type(result) == "number" then 
        print(result)
    end 
end

-- Call a verb by name with a pre-parsed args table.
function CLI:call(verbname, args)
    if not self.verbs[verbname] then
        self:throw("usage", "unknown verb '" .. verbname .. "'")
    end
    table.insert(self.verbstack, verbname)
    local ok, result = xpcall(
        function() return self.verbs[verbname][1](args) end,
        function(err)
            return { msg = err, trace = debug.traceback(nil, 2) }
        end
    )
    table.remove(self.verbstack)
    if not ok then
        self:throw("bug", result.msg, result.trace)
    end
    return result
end

-- Throw a named error and exit.
function CLI:throw(errtype, msg, ...)
    local handler = self.errors[errtype][1]
    if not handler then
        io.stderr:write("Unknown error type '" .. tostring(errtype) .. "'\n")
        io.stderr:write(tostring(msg) .. "\n")
        io.stderr:write(debug.traceback(nil, 2) .. "\n")
        os.exit(1)
    end
    io.stderr:write(handler(msg, ...) .. "\n")
    if self.errors[errtype].hint then 
        io.stderr:write(self.errors[errtype].hint .. "\n")
    end 
    os.exit(1)
end

-- onky need one
return CLI.new("vex")