---
vexid: install-vex-release-tarball-zip-1
vextype: atom
description: Install vex from a release tarball or zip
created: "2026-10-24 22:54:44"
modified: "2026-10-30 03:17:28"
status: done
---
Installing meant cloning the repo and symlinking `src/vex`. `install.sh` and `install.ps1` now install a release (or the clone) under a prefix and `--uninstall` removes it; `scripts/package.sh` builds the `.tar.gz`, `.zip` and `SHA256SUMS`. Documented in [[01 Installing vex]]; covered by `test/e2e/install_spec.lua`.