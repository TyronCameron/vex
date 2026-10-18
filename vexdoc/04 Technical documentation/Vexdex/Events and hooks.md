Every command fires two events through `src/lib/event.lua`:

- `pre-<command>` before the command changes anything.
- `post-<command>` after it finishes.

When a command starts, vex loads every `.lua` file in `.vex/events`, sorted by path. Each file registers handlers with `event:on '<event>' (handler)`. vex then calls the handlers for each event in the order they were registered, passing the focus the command acts on. An error raised by a `pre-` handler stops the command before anything is written.

See [[06 Configuring event hooks]] for examples.
