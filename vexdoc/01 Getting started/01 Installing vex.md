vex is a single LuaJIT script with no external services to stand up — installing it means getting the `vex` command on your `PATH` and (optionally) wiring up shell completion.

## Requirements

- **LuaJIT** (or any Lua ≥ 5.1 interpreter).
- A clone of the vex repository.
- The `vex/src` directory on your path.

## Running vex

The real entry point is `src/vex.lua`, launched through the `src/vex` shell wrapper (`src/vex.bat` on Windows). That wrapper resolves symlinks to find its own directory, points Lua's `package.path`/`package.cpath` at `src/`, and requires `vex`.

```txt
git clone <your fork or the vex repo>
cd vex
./src/vex help
```

> [!WARNING] `vex help` (and everything else) currently needs an existing `.vex` folder somewhere above you
> Confirmed by testing: `./src/vex help` — and every other command, including `init` itself — currently fails with "Not in a vex directory" if there's no `.vex` folder anywhere from your current directory up to the filesystem root. This is because loading the shell-completion plugin eagerly touches the task index, which refuses to initialise outside a `.vex` tree. It only goes unnoticed in vex's own repo because this repo already tracks its own backlog in a `.vex` folder at its root (see [[Home]]). There's no user-side workaround yet — see the next section, and `fix-init-requires-existing-vex-1` in this project's own vex tasks.

> [!NOTE] `lux.toml` is currently out of date
> The repo's `lux.toml` declares `[run] args = ["src/main.lua"]`, but `src/main.lua` doesn't exist — the real entry point is `src/vex.lua` / `src/vex`, as above. Use `./src/vex`, not `lux run`, until that's fixed.

To make `vex` callable from anywhere, symlink the wrapper onto your `PATH`, e.g.:

```txt
ln -s "$(pwd)/src/vex" /usr/local/bin/vex
```

## Initializing a project

Inside any project you want to track tasks for:

```txt
cd my-project-directory
vex init
```

This creates a `.vex` folder in the current directory (see [[01 Configuring vex (config.lua)]] and [[The index]] for what lives inside it), and once it exists, vex looks in parent directories for it before giving up — so it's safe to run vex commands from a subdirectory of an already-initialized project.

> [!WARNING] Confirmed broken on a genuinely fresh project
> As above: `vex init` currently fails the same way `vex help` does, for the same reason, on any machine/location that doesn't already have a `.vex` folder somewhere above it. Manually pre-creating an empty `.vex` folder doesn't help either — it just trips `init`'s own "already in a vex directory" guard instead, since both checks walk the same way up the directory tree. Until `fix-init-requires-existing-vex-1` lands, there's no known way to bootstrap vex in a brand new location — every example on this wiki that assumes a working `vex init` is describing intended, not currently-reachable, behaviour for a fresh project.

## Shell completion

vex ships a completion plugin (`src/plugin/vexcomplete.lua`). Generate the snippet for your shell and install it in your shell's startup file:

```txt
vex autocomplete bash       # or: zsh, fish, powershell
```

This prints a ready-to-paste snippet that calls `vex suggest <cursor-position> <tokens...>` behind the scenes to complete verbs, focuses, views, recipes, and flags as you type. You won't normally call `vex suggest` yourself — it's what the generated snippet calls for you.

## Next steps

Head to [[02 Creating your first task using vex]] for a five-minute walkthrough of `add`, `show`, and `resolve`.
