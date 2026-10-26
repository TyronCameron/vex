---
vexid: load-config-extensions-plugins-1
vextype: atom
description: "Load config, extensions and plugins from a global folder"
created: "2026-10-24 22:54:45"
modified: "2026-10-24 22:54:50"
status: done
---
An installed vex keeps its plugins inside the install, which an upgrade replaces, and had no user-level settings. `lfsext.globaldir` (`$VEX_HOME`, `%APPDATA%\vex`, `$XDG_CONFIG_HOME/vex`, `~/.config/vex`) is now read before `.vex` for `config.lua`, the extension folders and `plugin/`. Documented in [[01 Configuring vex (config.lua)]]; covered by `test/e2e/global_spec.lua`.