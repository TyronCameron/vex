Tasks are plain text files, so git and vex work together with a little care.

## What to commit

Commit the task files in `taskfolder`, `.vex/config.lua` and your extensions (`tasks`, `recipes`, `focuses`, `views`, `events`).

Keep `.vex/vexdex/` out of git by adding it to `.gitignore`. It holds the index, which vex rebuilds from the task files, and your saved focus, which is personal.

## After a clone, pull or checkout

The index is stale until you rebuild it:

```console
$ vex resolve all
```

This rereads every task file, so it also picks up files other people added, edited or deleted, and fails if any task is invalid. A task file moved by hand is still found by its filename.

## Merge conflicts

A task is a markdown file, so conflicts are ordinary text conflicts. Edit the file to remove the markers, keeping the right values, and run `vex resolve all`: it names any task that is still invalid.

## Checking before you commit

Make `vex resolve all` a `pre-commit` hook so that invalid tasks never reach the repository:

```console
$ cat .git/hooks/pre-commit
#!/bin/sh
vex resolve all
```

## Sharing a backlog

`owner` must be one of `taskowners` in `.vex/config.lua`, so commit that file and everyone assigns the same names. Each person keeps their own saved focus, so `vex focus all --filter owner:alice` is a personal view of a shared backlog.
