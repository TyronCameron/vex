Events go through one event manager, `src/lib/event.lua`. They fire at two levels:

- **Verbs.** `lib.cli` fires `pre-verb-<verb>` before every command runs and `post-verb-<verb>` after it finishes.
- **Actions.** The task, focus, view and recipe managers fire `pre-` and `post-` events around each public action, such as `pre-task-resolve` or `post-focus-write`.

At the end of loading, vex runs every `.lua` file in `.vex/events`, sorted by path, and each file registers its handlers. Handlers run in the order they were registered. A handler that raises an error stops the command with a `hook-failed` error naming the hook and the event. See [[06 Configuring event hooks]] for the full list of events and their args.

## Logs

The vexdex listens to every event and keeps two logs in `.vex/vexdex`:

- `verb-log.txt`: one line per command, `<time>\t<command line>`, written before the command runs.
- `event-log.txt`: one line per event, `<time>\t<event>\t<args>`.

Both keep the last `loglimit` lines (1000 by default, see [[01 Configuring vex (config.lua)]]). They are trimmed at the start of each command, so `event-log.txt` can run over the limit by one command's events.

Replaying `verb-log.txt` in order in a fresh `vex init` rebuilds the same tasks and focus. A replay can't reproduce three things: `created` and `modified` times, relative dates such as `tomorrow` (both take the time of the replay), and edits made to task files by hand.
