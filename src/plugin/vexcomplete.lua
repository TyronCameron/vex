local cli = require 'lib.cli'
local bootstrap = require 'core.bootstrap'
local focus = require 'core.focus'
local pretty = require 'lib.pretty'
local func = require 'lib.func'
local view = require 'core.view'

-- TODO: create a bootstrapper file. I'm reusing a lot of logic here.

local POWERSHELL_SCRIPT = [[
Register-ArgumentCompleter -Native -CommandName vex -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $tokens = $commandAst.CommandElements | ForEach-Object { $_.ToString() }
    $current = if ($wordToComplete -eq '') { $tokens.Count } else { $tokens.Count - 1 }
    vex suggest $current @tokens | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
]]

local BASH_SCRIPT = [[
_vex_complete() { mapfile -t COMPREPLY < <(vex suggest "$COMP_CWORD" "${COMP_WORDS[@]}"); }
complete -F _vex_complete vex
]]

local ZSH_SCRIPT = [[
_vex_complete() {
    local current=$(( CURRENT - 1 ))
    local completions
    completions=($(vex suggest "$current" "${words[@]}"))
    compadd -- $completions
}
compdef _vex_complete vex
]]

local FISH_SCRIPT = [[
function _vex_complete
    set tokens (commandline -opc)
    vex suggest (count $tokens) $tokens
end
complete -c vex -f -a "(_vex_complete)"
]]

local scripts = {
    powershell = {
        script = POWERSHELL_SCRIPT
    },
    bash = {
        script = BASH_SCRIPT
    },
    zsh = {
        script = ZSH_SCRIPT
    },
    fish = {
        script = FISH_SCRIPT
    }
}

local suggest = {}

cli:error 'unknown-shell' {
    function(shell)
        local str = "Shell of name `" .. tostring(shell) .. '` is not known. You can provide any of the following:' 
        for shell, _ in pairs(scripts) do
            str = str .. '\n' .. shell 
        end
        return str
    end
}

cli:verb "autocomplete" {
    function(args)
        local shell = args[1]
        if not shell then cli:throw('usage') end 
        if not scripts[shell] then cli:throw('unknown-shell', shell) end
        local snippet = scripts[shell].script
        return "Please copy the snippet below and install it in your rc file or equivalent:\n```lua\n" .. snippet .. '```'
    end,
    doc = "Installs autocomplete. You must provide your shell to the this function.",
    args = "shell",
    example = "vex autocomplete bash"
}

-- vex suggest vex foc<tab> => "focus" 
cli:verb "suggest" {
    function(args)
        return suggest.suggest(args)
    end,
    doc = "Installs autocomplete",
    args = "current Command...",
    example = "vex autocomplete"
}

function suggest.options(suggestions)
    if type(suggestions) == "table" then 
        return table.concat(suggestions, '\n')
    end 
    return tostring(suggestions)
end

local function parse_usage(usage)
    local pos, flags = {}, {}
    for token in usage:gmatch("%S+") do
        local flag = token:match("^%[%-%-(.-)%.?%.?%.?%]$")
        local positional = token:match("^%[(.-)%]$")
        if flag then
            table.insert(flags, flag)
        elseif positional then
            table.insert(pos, positional)
        end
    end
    return pos, flags
end

function suggest.next_arg_type(current, args)
    if #args == 0 or (#args == 1 and current == 1) then 
        return 'verb'
    end 
    local verbname = table.remove(args, 1)
    local template_positional_args, template_flag_args = parse_usage(cli.verbs[verbname].args)
   
    current = current - 1
    local lastargcntr = 0
    for _, arg in ipairs(args) do
        if type(arg) == "string" then 
            lastargcntr = lastargcntr + 1
        elseif type(arg) == "table" then 
            lastargcntr = lastargcntr + #arg
        end
    end
    
    local lastarg = args[#args]
    local iscomplete = current > lastargcntr 
    local isflag = (type(lastarg) == "string" and lastarg:sub(1, 2) == "--") or type(lastarg) == "table"

    if not iscomplete and not isflag then 
        local current_position = #args:positional()
        return template_positional_args[current_position] or 'unknown'
    end 

    if not iscomplete and isflag then 
        return template_flag_args[1] or 'unknown'
    end 

    if iscomplete and isflag then 
        local current_position = #args:positional()
        return template_positional_args[current_position + 1] or 'unknown'
    end 

    if iscomplete and not isflag then 
        local current_position = #args:positional()
        return template_positional_args[current_position + 1] or 'unknown'
    end 
end


function suggest.verb()
    local str = ''
    for verb in pairs(cli.verbs) do
        str = str .. verb .. '\n'
    end
    return str
end

function suggest.focus()
    local suggestions = func.keys(focus.named)
    table.insert(suggestions, 'prev')
    bootstrap()
    focus.focus('all'):each(function(vexid) return table.insert(suggestions, vexid) end)
    return suggestions
end

function suggest.view()
    return func.keys(view.views)
end

function suggest.recipe()
    local tasks, vexdex, config, recipe = bootstrap()
    return func.keys(recipe.recipes)
end

function suggest.fields()
    
end

function suggest.focusflags()
    return {
        '--select', '--filter', '--fuzzy', '--between',
        '--tree', '--reversetree', '--union', '--intersect',
        '--complement', '--xor', '--notin', '--onlyin', '--interpret'
    }
end

function suggest.unknown()
    return ''
end

-- vex suggest 2 vex focus --select field:value
--> args = 2 vex focus {select, field:value}
function suggest.suggest(args)
    local current = tonumber(table.remove(args, 1))
    table.remove(args, 1)
    --> args = focus {select, field:value}

    pretty.write('/home/tyronc/Nextcloud/projects/vex/.vex/current.txt', current, args)
    local next_arg_type = suggest.next_arg_type(current, args)
    pretty.append('/home/tyronc/Nextcloud/projects/vex/.vex/current.txt', next_arg_type or 'nil')

    if type(suggest[next_arg_type]) == "function" then 
        local suggestions = suggest[next_arg_type]()
        local printable_suggestions = suggest.options(suggestions)
        pretty.append('/home/tyronc/Nextcloud/projects/vex/.vex/current.txt', printable_suggestions or 'nil')
        return printable_suggestions
    end 
end 
