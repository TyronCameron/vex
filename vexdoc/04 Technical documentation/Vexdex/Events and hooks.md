The intended design (per [[Vex]]) is that every verb fires two events:

- `pre-[verb]`
- `post-[verb]`

**Currently, this doesn't exist.** `src/lib/event.lua` — the module that would own dispatching these — is a one-line stub: `return {}`. No verb in `src/core/verbs.lua` fires anything, and `.vex/events` (created by `vex init`) is never read. Tracked as `implement-event-hooks-1` in the project's own vex tasks; see [[Configuring event hooks]] for the user-facing writeup of the intended design and what to do instead in the meantime.
