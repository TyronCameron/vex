---
vexid: make-vexids-phrase-aware-length-1
vextype: task
description: Make vexids phrase-aware and length-flexible
created: "2026-10-15 13:04:51"
modified: "2026-10-15 13:04:57"
status: done
---
The default tagger (src/default/canonicalvexid.lua) took the first 4 non-filler words, so ids were truncated at a fixed count, leaked prepositions like into/outside, glued punctuated words together (luxtoml, focusfocus) and dropped negation. It now keeps the first sentence, splits on punctuation (keeping the first of slash alternatives), drops filler words and -ly adverbs, keeps negation (doesn't -> not), and treats prepositions/subordinators as phrase boundaries: the main clause fills a 32-char / 6-word budget first, prepositional phrases only if room remains. No data files or dependencies.