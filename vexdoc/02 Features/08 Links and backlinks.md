A task links to another by holding its vexid in `children`, `options`, `decision` or `dependencies`. In the task file a link is written `[[vexid]]`, so Obsidian draws the graph. vex checks every link when it resolves: the target must exist, a child has one parent, and dependencies can't form a cycle.

## Links as fields

Two transients answer "what does this task link to?" and "what links to it?". They are never stored, and work wherever a field does:

| Transient | Value |
| --- | --- |
| `forwardlinks` | The vexids of the tasks this task links to, through any field. |
| `backlinks` | The vexids of the tasks that link to this task, through any field. |

```console
$ vex get migrate-existing-invoices-1 --forwardlinks --backlinks
	ship-billing-rewrite-1,write-cutover-runbook-1
```

The task links to nothing, and is linked from its parent and from a task that depends on it. `backlinks` come from the index, so they are as fresh as the last `vex resolve`.

## Walking links

`--step` moves one hop and `--tree` follows links until they run out ([[05 Getting into focus]]):

```console
$ vex focus migrate-existing-invoices-1 --step backlinks
Focusing on 2 vexes
$ vex focus migrate-existing-invoices-1 --tree backlinks
Focusing on 3 vexes
```

The second focus adds the task itself to the two above. `--step children` and `--tree children` walk the abstract hierarchy the same way. With no field, `--step`, `--tree` and `--reversetree` follow every link.

## What follows from a change

Links are why one change can touch many files:

- **Resolving a task** resolves every task linked to it or from it, transitively, so derived fields stay right, and re-files them: a parent's change moves its children, and a finished dependency moves its dependents ([[01 Configuring vex (config.lua)#Grouping task files into folders]]).
- **Removing a task** strips its vexid from every task that linked to it, then resolves them, so no link is left dangling.

An abstract's `status` also follows its children ([[06 Status and state machines]]).
