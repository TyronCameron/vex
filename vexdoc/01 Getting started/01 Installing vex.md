vex is a single LuaJIT program with no services to run. Installing it means putting the `vex` command on your path and, optionally, enabling shell completion.

## Requirements

- LuaJIT.

## Installing a release

Every [release](https://github.com/TyronCameron/vex/releases) is a `.tar.gz` and a `.zip` holding the Lua sources and an installer. On Linux and macOS:

```console
$ curl -fsSL https://raw.githubusercontent.com/TyronCameron/vex/main/install.sh | sh
$ vex version
```

That downloads the latest release and puts it under `~/.local` (`lib/vex` holds the program, `bin/vex` is the command). Set `PREFIX` to install elsewhere and `VEX_VERSION` to pick a release:

```console
$ curl -fsSL https://raw.githubusercontent.com/TyronCameron/vex/main/install.sh | PREFIX=/usr/local VEX_VERSION=0.0.1 sh
```

Or unpack a release yourself and run its installer; running it again upgrades vex:

```console
$ tar -xzf vex-0.0.1.tar.gz
$ sh vex-0.0.1/install.sh
$ sh vex-0.0.1/install.sh --uninstall
```

If `~/.local/bin` is not on your `PATH`, the installer says so.

On Windows, unzip a release and run the installer from PowerShell. It copies vex to `%LOCALAPPDATA%\vex` and adds that folder to your user `PATH`:

```console
$ .\install.ps1
$ .\install.ps1 -Uninstall
```

Your tasks, `.vex` folders and global folder (see [[01 Configuring vex (config.lua)#The global folder]]) are never touched by installing, upgrading or uninstalling.

## Running from a clone

To work on vex itself, run it from a clone. `src/vex` (`src/vex.bat` on Windows) finds its own directory, sets up Lua's module paths and runs `src/vex.lua`:

```console
$ git clone https://github.com/TyronCameron/vex.git
$ cd vex
$ ./src/vex help
```

`just install` installs the clone the same way a release does.

## Initialising a project

In any folder you want to track tasks for:

```console
$ cd my-project
$ vex init
```

This creates a `.vex` folder. vex looks for the nearest `.vex` in the current folder or any folder above it, so every command works from anywhere inside the project. See [[01 Configuring vex (config.lua)]] and [[The index]] for what `.vex` holds.

## Using vex with git

Commit your task files and `.vex/config.lua`, along with any extensions in `.vex`. Don't commit the index: add `.vex/vexdex/` to your `.gitignore`. vex rebuilds it from the task files with:

```console
$ vex resolve all
```

Run this after cloning, pulling or switching branches.

## Shell completion

Print the completion script for your shell and add it to your shell's startup file:

```console
$ vex autocomplete bash       # or zsh, fish, powershell
```

The script completes verbs, focuses, views, recipes and flags as you type.

## Next steps

[[02 Creating your first task using vex]] walks through the core commands.
