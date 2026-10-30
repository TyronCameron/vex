---
vexid: publish-github-release-version-1
vextype: atom
description: Publish a GitHub release when a version tag is pushed
created: "2026-10-24 22:54:44"
modified: "2026-10-30 03:17:28"
status: done
---
`.github/workflows/release.yml` runs `just test`, packages with `scripts/package.sh` and creates the release for a pushed `v*` tag (or a manual dispatch). It cannot be run outside GitHub, so check the first real release. `lux.toml` now installs the `vex` binary, but publishing to LuaRocks with `lux upload` is not wired in yet.