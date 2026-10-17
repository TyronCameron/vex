vex is a single LuaJIT program with no services to run. Installing it means putting the `vex` command on your path and, optionally, enabling shell completion.

## Requirements

- LuaJIT.
- A clone of the vex repository.

## Running vex

`src/vex` is the entry point (`src/vex.bat` on Windows). It finds its own directory, sets up Lua's module paths and runs `src/vex.lua`.

```txt
git clone <the vex repository>
cd vex
./src/vex help
```

To run `vex` from anywhere, link the wrapper onto your path:

```txt
ln -s "$(pwd)/src/vex" /usr/local/bin/vex
```

## Initialising a project

In any folder you want to track tasks for:

```txt
cd my-project
vex init
```

This creates a `.vex` folder. vex looks for the nearest `.vex` in the current folder or any folder above it, so every command works from anywhere inside the project. See [[01 Configuring vex (config.lua)]] and [[The index]] for what `.vex` holds.

## Using vex with git

Commit your task files and `.vex/config.lua`, along with any extensions in `.vex`. Don't commit the index: add `.vex/vexdex/` to your `.gitignore`. vex rebuilds it from the task files with:

```txt
vex resolve all
```

Run this after cloning, pulling or switching branches.

## Shell completion

Print the completion script for your shell and add it to your shell's startup file:

```txt
vex autocomplete bash       # or zsh, fish, powershell
```

The script completes verbs, focuses, views, recipes and flags as you type.

## Next steps

[[02 Creating your first task using vex]] walks through the core commands.
