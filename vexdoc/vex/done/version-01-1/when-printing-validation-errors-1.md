---
vexid: when-printing-validation-errors-1
vextype: atom
description: "When printing validation errors, pretty print them"
created: "2026-07-10 22:12:48"
modified: "2026-10-30 07:09:14"
status: done
---

Pretty print validation errors. At the moment we get something like this 

```txt
❯  vex recipe abstract Bugs 
The validation step failed during resolution for vexid `bugs-1`.
Validation failed:
Validation failed:
Validation failed:


Context:
        Path: `description`
        Schema types: `atleast.all.words`
        Schema: `words`
        Instance: `Bugs `

Context:
        Path: `description`
        Schema types: `atleast.all`
        Schema: `all`
        Instance: `Bugs `

Context:
        Path: ``
        Schema types: `atleast`
        Schema: `atleast`
        Instance: `{
  created = 1792359276,
  description = "Bugs",
  modified = 1792359276,
  status = "todo",
  vexid = "bugs-1",
  vextype = "abstract"
}       `.

Ensure that data is correct and that the tasktype definitions in `config.lua` are sound.
```

The nesting is probably unavoidable but it is not easy to understand this error.
Consider how programming languages present error first and then a stacktrace of where the error happened.
First prize is to show error message first and then the stack. It would be wonderful to have some kind of indication about the stack height, etc. 
Maybe some tree-like arrows (don't indent more than space or two each time), and bold over the actual message, would be ideal.
