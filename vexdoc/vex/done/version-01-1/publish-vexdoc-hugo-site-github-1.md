---
vexid: publish-vexdoc-hugo-site-github-1
vextype: atom
description: Publish vexdoc as a Hugo site on GitHub Pages
created: "2026-10-19 09:26:52"
modified: "2026-10-30 03:20:22"
status: done
---

`.github/workflows/pages.yml` builds `vexdoc/` on every push to `main` with `site/build.sh` (obsidian-export for the wikilinks, Hugo with the `dark-theme-editor` theme) and pushes it to the `gh-pages` branch. GitHub Pages must be set to deploy from that branch in the repository settings.
